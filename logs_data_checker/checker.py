#
# IBM Confidential
# OCO Source Materials
#
# Licensed Materials - Property of IBM
#
# 5737-M96
# (C) Copyright IBM Corp. 2020 All Rights Reserved.
#
# The source code for this program is not published or otherwise
# divested of its trade secrets, irrespective of what has been
# deposited with the U.S. Copyright Office.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#

import argparse
import calendar
import datetime
import json
import logging
import math
import os
import random
import time
from concurrent import futures
from itertools import islice
from pathlib import Path

import click
import dateutil
import fastjsonschema  # for faster validation per https://www.peterbe.com/plog/jsonschema-validate-10x-faster-in-python
from dateutil.parser import parse as date_parse
from importlib_resources import files

from logs_data_checker import resources

LOG_SCHEMA_FILE = "log_schema.json"
logger = logging.getLogger(__name__)
BLOCK_SIZE = 10000


class FileInBatches(object):
    """ Iterator to load the file by batches
        each batch has BLOCK_SIZE lines

    """

    def __init__(self, file_path: Path):
        self.__file = open(file_path, "r", encoding="utf-8")
        self.count = 0

    def __iter__(self):
        return self

    def __next__(self):
        if self.__file.closed:
            raise StopIteration
        line = list(islice(self.__file, BLOCK_SIZE))
        if line:
            self.count += 1
            return line, (self.count - 1)
        else:
            self.__file.close()
            raise StopIteration


def n_line(file):
    """ Return the number of lines for a file

    Args:
        file (str): File path

    Returns:
        int: number of lines
    """
    count = 0
    buffer = 16 * 1024 * 1024  # buffer=16MB
    with open(file, "rb") as inf:
        while True:
            block = inf.read(buffer)
            if not block:
                break
            count += block.count(b"\n")
    return count


class VerificationResult(object):
    """ Result of a check
    """

    def __init__(self, error_type: str, message: str):
        self.error_type = error_type
        self.message = message


def validate_normalized(line):
    """ Validate the log in json with respects to the schema

    Args:
        line (str): log in json format

    Returns:
        VerificationResult: if any errors, else None
    """
    try:
        validator(line)
    except fastjsonschema.JsonSchemaException as e:
        return VerificationResult("[Validation Error]", e.message)
    return None


def check_timestamp_digits(timestamp):
    """ Check the timestamp format. We expect 13 digits (to milliseconds) timestamp

    Args:
        timestamp (int): timestamp in epoch

    Returns:
        VerificationResult: if any errors, else None
    """
    if isinstance(timestamp, int) and int(math.log10(timestamp)) + 1 == 13:
        return None
    return VerificationResult("[Timestamp Error]", "Incorrect timestamp")


def unix_time_millis(time_str):
    """ Parse the time str and covert to epoch in millisecond
    e.g.
        unix_time_millis("2020-01-10 15:12:15.680000") = 1578669135000

    Note that the parser support only the seconds. The epoch is naively converted to millisecond.

    Args:
        time_str (str): Time string

    Returns:
        int: epoch in millisecond
    """
    dt = date_parse(time_str)
    return calendar.timegm(dt.timetuple()) * 1000


def time_sync_tolerance(time1: int, time2: int, tor: int = 1000):
    """ Comapre timestamp and utc_timestamp to seconds

    Args:
        time1 (int): [description]
        time2 (int): [description]
        tor (int, optional): [description]. Defaults to 5.

    Returns:
        bool: True if diff is under tor
    """
    if abs(time1 - time2) < tor:
        return True
    return False


def check_time(line):
    """ Check the consistency between line["timestamp"] and line["utc_timestamp"]

    Args:
        line (Dict): a line of log of json format, parsed as a dict

    Returns:
        VerificationResult: if any errors, else None
    """
    if "timestamp" not in line:
        return VerificationResult("[Time Error]", 'Missing "timestamp"')
    if "utc_timestamp" in line:
        try:
            assert time_sync_tolerance(
                line["timestamp"], unix_time_millis(line["utc_timestamp"])
            )
        except dateutil.parser._parser.ParserError as e:  # pylint: disable=protected-access
            return VerificationResult("[Time Error]", str(e))
        except AssertionError as e:
            return VerificationResult(
                "[Time Error]", '"timestamp" and "utc_timestamp" are not consistent'
            )
    return None


def line_check(line):
    """ Run checking for a line

    Args:
        line ([type]): [description]

    Returns:
        [type]: [description]
    """
    json_line = json.loads(line)

    errors = [
        "%s: %s" % (e.error_type, e.message)
        for e in [
            validate_normalized(json_line),
            check_timestamp_digits(json_line["timestamp"])
            if "timestamp" in json_line
            else None,
            check_time(json_line),
        ]
        if e
    ]

    return errors


with open(files(resources) / LOG_SCHEMA_FILE) as inf:
    schema = json.load(inf)
validator = fastjsonschema.compile(schema)


def _pcheck(block):
    """ Helper for multiprocesses: check a block of logs

    Args:
        block List[List[str], int]: lines, block_id

    Returns:
        [type]: [description]
    """

    results = []
    lines, block_id = block

    for li, line in enumerate(lines):
        json_line = json.loads(line)
        result = [
            "%s: %s" % (e.error_type, e.message)
            for e in [
                validate_normalized(json_line),
                check_timestamp_digits(json_line["timestamp"])
                if "timestamp" in json_line
                else None,
                check_time(json_line),
            ]
            if e
        ]
        global_line_number = block_id * BLOCK_SIZE + li
        results.append((global_line_number, result))
    return results


def parallel_checking(file: Path, parallism: int):
    """ Check the file in parallel

    Args:
        file (Path): Input file
        parallism (int): number of processes
    """
    batches = FileInBatches(file)
    with futures.ProcessPoolExecutor(max_workers=parallism) as executor:
        tasks = {
            executor.submit(_pcheck, block): (block_index, block)
            for block_index, block in enumerate(batches)
        }
    for future in futures.as_completed(tasks):
        errs = future.result()
        for line_cnt, e in errs:
            if len(e) > 0:
                print("Line %d has %d errors: %s" % (line_cnt, len(e), ", ".join(e)))


@click.command()
@click.argument("file", nargs=1, type=click.Path(exists=True))
@click.option(
    "-n",
    "--sample-size",
    default=1000,
    type=int,
    help="SAMPLE_SIZE: Number of samples. Default:1000",
)
@click.option(
    "-r",
    "--random-sampling",
    default=False,
    is_flag=True,
    help="Randomly check SAMPLE_SIZE line of logs",
)
@click.option(
    "-f",
    "--full",
    default=False,
    is_flag=True,
    help="Run checks for all the logs, the results are out of order",
)
@click.option(
    "-p",
    "--parallel",
    default=4,
    type=int,
    help="Number of parallelism for running the full check",
)
def main(file, sample_size, random_sampling, full, parallel):
    """ Entry point for the checker

    Args:
        file (str): input file
        sample_size (int): Number of samples. Default:1000
        random_sampling (bool): Randomly check $sample_size line of logs. Default:False
        full (bool): Run checks for all the logs, the results are out of order. Default:False
        parallel ([type]): Number of parallelism for running the full check
    """
    if full:
        parallel_checking(file, parallel)
        return

    sampled_logs = []
    file_cnt = n_line(file)
    if sample_size > file_cnt:
        random_sampling = False

    if random_sampling:
        samples = set(random.sample(range(0, file_cnt), sample_size))
        cnt = 0
        with open(file, "r", encoding="utf-8") as inf:
            for i in inf:
                if cnt in samples:
                    sampled_logs.append(i)
                cnt += 1
        samples = sorted(list(samples))
    else:
        cnt = 0
        with open(file, "r", encoding="utf-8") as inf:
            for i in inf:
                sampled_logs.append(i)
                cnt += 1
                if cnt == sample_size:
                    break
        samples = range(sample_size)

    for line_num, line in zip(samples, sampled_logs):
        errors = line_check(line)
        if len(errors) > 0:
            print(
                "Line %d has %d errors: %s" % (line_num, len(errors), ", ".join(errors))
            )


if __name__ == "__main__":
    main()
