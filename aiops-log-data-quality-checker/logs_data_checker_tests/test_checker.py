import io
import json
import sys
import unittest
from contextlib import redirect_stdout

import pytest
from click.testing import CliRunner
from importlib_resources import files

import logs_data_checker
import logs_data_checker_tests
from logs_data_checker import checker, resources
from logs_data_checker.checker import (
    VerificationResult,
    check_time,
    check_timestamp_digits,
    line_check,
    main,
    validate_normalized,
)

## Test files
GOOD_INPUT = files(logs_data_checker_tests.data) / "test_main_good.input"
BAD_INPUT = files(logs_data_checker_tests.data) / "test_main_bad.input"
BAD_INPUT_RES = files(logs_data_checker_tests.data) / "test_main_bad.errors"


@pytest.fixture
def bad_input_results(scope="session"):
    """ Fixture for loading the expected outcome for bad inpput

    Returns:
        List[str]: expected results
    """
    res = []
    with BAD_INPUT_RES.open("r") as inf:
        for i in inf:
            res.append(i.strip())
    return res


def test_timestamp():
    """test check_time()
    """
    j = {}
    res = check_time(j)
    assert isinstance(res, VerificationResult)
    assert res.message == 'Missing "timestamp"'

    j = {"utc_timestamp": "not a time", "timestamp": 5786691356811}
    res = check_time(j)
    assert isinstance(res, VerificationResult)
    assert res.message == "Unknown string format: not a time"

    j = {"utc_timestamp": "2020-01-10 15:12:11.000000", "timestamp": 1578669135680}
    res = check_time(j)
    assert isinstance(res, VerificationResult)
    assert res.message == '"timestamp" and "utc_timestamp" are not consistent'

    j = {"utc_timestamp": "2020-01-10 15:12:15.680000", "timestamp": 1578669135680}
    assert check_time(j) is None


def test_check_timestamp_digits():
    """ test check_timestamp_digits()
    """
    assert check_timestamp_digits(5786691356811) is None
    assert isinstance(check_timestamp_digits(57866913568), VerificationResult)


def test_fields():
    """ test validate_normalized()
    """
    with (
        files(logs_data_checker_tests.data) / "normalized_example.json"
    ).open() as inf:
        data = json.load(inf)

    assert validate_normalized(data) is None
    for field in data:
        temp = data[field]
        data.pop(field)
        assert isinstance(validate_normalized(data), VerificationResult)
        data[field] = temp


def test_checker_random(bad_input_results):
    """ Test the check.py in random mode

    Args:
        bad_input_results (fixture): expected results
    """
    runner = CliRunner()

    # bad input, -r, sample_size > file_size, random selection is not used
    my_stdout = io.StringIO()
    with redirect_stdout(my_stdout):
        run = runner.invoke(main, [str(BAD_INPUT), "-r"])
    results = run.stdout.strip().split("\n")
    assert results == bad_input_results

    # bad input, -r, sample_size > file_size, random selection is not used
    my_stdout = io.StringIO()
    with redirect_stdout(my_stdout):
        run = runner.invoke(main, [str(GOOD_INPUT), "-r"])
    assert run.stdout.strip() == ""

    # bad input, -r, sample_size < file_size, randoml select sample_size
    sample_size = 5
    my_stdout = io.StringIO()
    with redirect_stdout(my_stdout):
        run = runner.invoke(main, [str(BAD_INPUT), "-r", "-n", sample_size])
    results = run.stdout.strip().split("\n")
    assert len(results) <= sample_size  # <= cause there are good cases in the bad input
    for i in results:
        assert i in bad_input_results

    # good input, -r, sample_size < file_size, randoml select sample_size
    my_stdout = io.StringIO()
    with redirect_stdout(my_stdout):
        run = runner.invoke(main, [str(GOOD_INPUT), "-r"])
    assert len(results) <= sample_size  # <= cause there are good cases in the bad input
    assert run.stdout.strip() == ""


def test_checker_full(bad_input_results, monkeypatch):
    """ Test the check.py in full mode

    Args:
        bad_input_results (fixture): expected results
    """
    runner = CliRunner()
    monkeypatch.setattr(checker, "BLOCK_SIZE", 4)  # patching the BLOCK_SIZE for testing

    # bad input, -p 1 -f
    my_stdout = io.StringIO()
    with redirect_stdout(my_stdout):
        run = runner.invoke(main, [str(BAD_INPUT), "-p", "1", "-f"])

    # sorted by line number
    results = sorted(run.stdout.strip().split("\n"), key=lambda x: int(x.split()[1]))
    assert results == bad_input_results

    # good input, -p 1 -f
    my_stdout = io.StringIO()
    with redirect_stdout(my_stdout):
        # runner = CliRunner()
        run = runner.invoke(main, [str(GOOD_INPUT), "-p", "1", "-f"])
    assert run.stdout.strip() == ""

    # bad input, -p 2 -f
    my_stdout = io.StringIO()
    with redirect_stdout(my_stdout):
        run = runner.invoke(main, [str(BAD_INPUT), "-p", "2", "-f"])

    # sorted by line number
    results = sorted(run.stdout.strip().split("\n"), key=lambda x: int(x.split()[1]))
    assert results == bad_input_results

    # good input, -p 3 -f
    my_stdout = io.StringIO()
    with redirect_stdout(my_stdout):
        # runner = CliRunner()
        run = runner.invoke(main, [str(GOOD_INPUT), "-p", "3", "-f"])
    assert run.stdout.strip() == ""


def test_checker_default(bad_input_results):
    """ Test the check.py in default mode

    Args:
        bad_input_results (fixture): expected results
    """
    runner = CliRunner()
    my_stdout = io.StringIO()
    with redirect_stdout(my_stdout):
        run = runner.invoke(main, [str(BAD_INPUT)],)
    results = run.stdout.strip().split("\n")
    # print(results)
    # print("====")
    # print(bad_input_results)
    for i, j in zip(results, bad_input_results):
        if i != j:
            print(i)
            print(j)
            print("====")
    assert results == bad_input_results

    my_stdout = io.StringIO()
    with redirect_stdout(my_stdout):
        # runner = CliRunner()
        run = runner.invoke(main, [str(GOOD_INPUT)],)
    assert run.stdout.strip() == ""

    # test sample size
    my_stdout = io.StringIO()
    sample_size = 3
    with redirect_stdout(my_stdout):
        run = runner.invoke(main, [str(BAD_INPUT), "-n", str(sample_size)],)
    results = run.stdout.strip().split("\n")
    # 2nd and 7th lines in bad_input are good, which don't cause error
    assert results == bad_input_results[:2]
