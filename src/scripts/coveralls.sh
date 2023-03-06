#!/bin/bash

curl -sL https://github.com/coverallsapp/coverage-reporter/releases/latest/download/coveralls-linux.tar.gz | tar -xz

args=""
if "${COVERALLS_VERBOSE}"; then
  args="${args} --debug"
fi

if "${COVERALLS_DRY_RUN}"; then
  args="${args} --dry-run"
fi

if [ ! "${COVERALLS_REPO_TOKEN}" ]; then
  COVERALLS_REPO_TOKEN=$(printenv "${COVERALLS_REPO_TOKEN_ENV}") || (echo "Token not configured" && exit 1)
  export COVERALLS_REPO_TOKEN
fi

if [ "${COVERALLS_DONE}" == "1" ]; then
  echo "Sending parallel finish webhook"

  # shellcheck disable=SC2086
  ./coveralls --done ${args}

  exit 0
fi

# Check for coverage file presence
if [ -n "${COVERALLS_COVERAGE_FILE}" ]; then
  if [ -r "${COVERALLS_COVERAGE_FILE}" ]; then
    args="${args} --file ${COVERALLS_COVERAGE_FILE}"
  else
    echo "Please specify a valid 'coverage_file' parameter. File doesn't exist or is not readable."
    exit 1
  fi
fi

if [ -n "${COVERALLS_BASE_PATH}" ]; then
  args="${args} --base-path ${COVERALLS_BASE_PATH}"
fi

# shellcheck disable=SC2086
./coveralls $args
