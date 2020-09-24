# data-quality-checker

The data training quality checker for AIOps log training

## Prequisite

* Install dependencies
  * `pip install requirements/base.txt`
  * `pip install requirements/test.txt` for running unit test
* Set ENV
  * Add the path of this repo in `PYTHONPATH`, e.g. `export PYTHONPATH=/Users/ME/data-quality-checker:$PYTHONPATH`

## Run the data checker
  * Usage:

  ```
    Usage: checker.py [OPTIONS] FILE

    Options:
      -n, --sample-size INTEGER  SAMPLE_SIZE: Number of samples. Default:1000
      -r, --random-sampling      Randomly check SAMPLE_SIZE line of logs
      -f, --full                 Run checks for all the logs, the results are out of order.
      -p, --parallel INTEGER    Number of parallelism for running the full check. Default:4
      --help                     Show this message and exit.
  ```

  * Default: `python checker.py TEST_LOGS_FILE >results`
    * The fist `SAMPLE_SIZE` lines will be checked and reported if there is any problem found.
    * The `SAMPLE_SIZE`  can be set by `-n`. e.g. `-n 10000`
    * It runs faster when pipe the output to a file.
  * Random sampling: `python -r checker.py TEST_LOGS_FILE >results`
    * `SAMPLE_SIZE` lines will be sampled from the input file if it has more than `SAMPLE_SIZE` lines. These lines will be checked and reorted if there is any problem found.
  * Full scanning: `python -f checker.py TEST_LOGS_FILE >results`
    * Check the all the logs in the file. Results will be not be in the original order.
    * The number of parallism can be set by `-p`. e.g. `-p 8`
    * For reference, checking 10M logs takes around 5 minutes with default parallism on a 2019 Mac Book Pro.

## Run unit test
  * `pytest logs_data_checker_tests -s --cov=logs_data_checker --cov-report term-missing --cov-report cov.xml`




## Contributing
Pull requests are very welcome! Make sure that your patches are tested. Ideally create a topic branch for every separate change you make. For example:

1. Fork the repo
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

Please also check [CONTRIBUTING](CONTRIBUTING.md)

**Note:** Make sure you update the [Changelog](CHANGELOG.md) each time you add, remove, or update sample files.

## License & Authors

If you would like to see the detailed LICENSE click [here](LICENSE).

- Author: New OpenSource IBMer <new-opensource-ibmer@ibm.com>

```text
Copyright:: 2019- IBM, Inc

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```