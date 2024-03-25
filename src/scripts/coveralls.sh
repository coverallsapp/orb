#!/bin/bash

curl -sLO https://github.com/coverallsapp/coverage-reporter/releases/latest/download/coveralls-linux.tar.gz
curl -sLO https://github.com/coverallsapp/coverage-reporter/releases/latest/download/coveralls-checksums.txt
grep coveralls-linux.tar.gz coveralls-checksums.txt | sha256sum --check
tar -xzf coveralls-linux.tar.gz

echo "Parsing args"
if [ "${COVERALLS_VERBOSE}" == "1" ]; then
  args="${args} --debug"
fi

echo Dry run - "${COVERALLS_DRY_RUN}"
if [ "${COVERALLS_DRY_RUN}" == "1" ]; then
  args="${args} --dry-run"
fi

if [ -z "${COVERALLS_REPO_TOKEN}" ]; then
  # shellcheck disable=SC2155
  export COVERALLS_REPO_TOKEN=$(printenv "${COVERALLS_REPO_TOKEN_ENV}")
fi

if [ "${COVERALLS_MEASURE}" == "1" ]; then
  args="${args} --measure"
fi

if [ "${COVERALLS_FAIL_ON_ERROR}" != "1" ]; then
  args="${args} --no-fail"
fi

if [ "${COVERALLS_DONE}" == "1" ]; then
  echo "Reporting parallel done"

  set -x

  # shellcheck disable=SC2086
  ./coveralls 'done' ${args}

  exit 0
fi

if [ -n "${COVERALLS_BASE_PATH}" ]; then
  args="${args} --base-path ${COVERALLS_BASE_PATH}"
fi

if [ -n "${COVERALLS_COVERAGE_FORMAT}" ]; then
  args="${args} --format ${COVERALLS_COVERAGE_FORMAT}"
fi

# Check for coverage file presence
if [ -n "${COVERALLS_COVERAGE_FILE}" ]; then
  coverage_file="$(readlink -f "$COVERALLS_COVERAGE_FILE")"
  if [ ! -e "${coverage_file}" ]; then
    echo "Please specify a valid 'coverage_file' parameter. File doesn't exist. Filename: ${COVERALLS_COVERAGE_FILE}"
    exit 1
  elif [ ! -r "${coverage_file}" ]; then
    echo "Please specify a valid 'coverage_file' parameter. File is not readable. Filename: ${COVERALLS_COVERAGE_FILE}"
    exit 1
  elif [ ! -f "${coverage_file}" ]; then
    echo "Please specify a valid 'coverage_file' parameter. File specified is not a regular file. Filename: ${COVERALLS_COVERAGE_FILE}"
    exit 1
  fi

  args="${args} ${coverage_file}"
fi

if [ -n "${COVERALLS_COVERAGE_FILES}" ]; then
  args="${args} ${COVERALLS_COVERAGE_FILES}"
fi

echo "Reporting coverage"

set -x
# shellcheck disable=SC2086
./coveralls report $args
set +x

exit_status=$?
if [ "${COVERALLS_FAIL_ON_ERROR}" != "1" ]; then
  exit_status=0
fi
exit "${exit_status}"
