#!/bin/bash

# Enable set -x debugging if COVERALLS_DEBUG or COVERALLS_VERBOSE (deprecated) is set to "1"
if [ "${COVERALLS_DEBUG}" == "1" ] || [ "${COVERALLS_VERBOSE}" == "1" ]; then
  set -x
fi

# Determine which version of coverage-reporter to download
if [ -z "$COVERALLS_REPORTER_VERSION" ] || [ "$COVERALLS_REPORTER_VERSION" == "latest" ]; then
  asset_path="latest/download"
else
  asset_path="download/${COVERALLS_REPORTER_VERSION}"
fi

# Download the Coveralls binary and verify the checksum
if ! curl -sLO "https://github.com/coverallsapp/coverage-reporter/releases/${asset_path}/coveralls-linux.tar.gz" ||
   ! curl -sLO "https://github.com/coverallsapp/coverage-reporter/releases/${asset_path}/coveralls-checksums.txt" ||
   ! grep coveralls-linux.tar.gz coveralls-checksums.txt | sha256sum --check ||
   ! tar -xzf coveralls-linux.tar.gz; then
  echo "Failed to download or verify coveralls binary."
  [ "${COVERALLS_FAIL_ON_ERROR}" != "1" ] && exit 0
  exit 1
fi

# Ensure the binary exists before attempting to run it
if [ ! -f ./coveralls ]; then
  echo "Coveralls binary not found after extraction."
  [ "${COVERALLS_FAIL_ON_ERROR}" != "1" ] && exit 0
  exit 1
fi

# Output the version of the installed coverage reporter
echo "Installed coverage reporter version:"
./coveralls --version || echo "Failed to retrieve version"

# Pass the --debug flag to coverage-reporter if COVERALLS_DEBUG or COVERALLS_VERBOSE (deprecated) is set to "1"
echo "Parsing args"
if [ "${COVERALLS_DEBUG}" == "1" ] || [ "${COVERALLS_VERBOSE}" == "1" ]; then
  args="${args} --debug"
fi

if [ "${COVERALLS_DRY_RUN}" == "1" ]; then
  echo Dry run - "${COVERALLS_DRY_RUN}"
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
  if ! ./coveralls 'done' ${args}; then
    # If fail_on_error is not set to "1", override the exit status to 0
    [ "${COVERALLS_FAIL_ON_ERROR}" != "1" ] && exit 0
    exit 1
  fi

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
if ! ./coveralls report $args; then
  # If fail_on_error is not set to "1", override the exit status to 0
  [ "${COVERALLS_FAIL_ON_ERROR}" != "1" ] && exit 0
  exit 1
fi
