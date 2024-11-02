#!/bin/bash

# Enable set -x debugging if COVERALLS_DEBUG or COVERALLS_VERBOSE (deprecated) is set to "1"
if [ "${COVERALLS_DEBUG}" == "1" ] || [ "${COVERALLS_VERBOSE}" == "1" ]; then
  set -x
fi

# Determine which version of coverage-reporter to download
if [ -z "$COVERAGE_REPORTER_VERSION" ] || [ "$COVERAGE_REPORTER_VERSION" == "latest" ]; then
  asset_path="latest/download"
else
  asset_path="download/${COVERAGE_REPORTER_VERSION}"
fi

# Determine the platform-specific filename:
# This logic is necessary due to the introduction of multiple platform support starting from v0.6.15.
# It selects the correct filename based on the specified platform, and version, while ensuring
# backward compatibility with earlier versions that only supported a generic Linux binary (for x86_64).

# Function to compare version numbers
version_ge() {
  # Compare two version numbers
  [ "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1" ]
}

# Determine platform-specific filename
case "${COVERAGE_REPORTER_PLATFORM}" in
  x86_64|"")
    if version_ge "$COVERAGE_REPORTER_VERSION" "v0.6.15"; then
      platform_filename="coveralls-linux-x86_64.tar.gz"
    else
      platform_filename="coveralls-linux.tar.gz"
    fi
    ;;
  aarch64|arm64)
    if version_ge "$COVERAGE_REPORTER_VERSION" "v0.6.15"; then
      platform_filename="coveralls-linux-aarch64.tar.gz"
    else
      echo "Warning: The aarch64/arm64 platform is only supported from version v0.6.15 onwards. Proceeding with v0.6.15." >&2
      asset_path="download/v0.6.15"
      platform_filename="coveralls-linux-aarch64.tar.gz"
    fi
    ;;
  *)
    echo "Warning: Unsupported platform: ${COVERAGE_REPORTER_PLATFORM}. The default x86_64 version will be used." >&2
    if version_ge "$COVERAGE_REPORTER_VERSION" "v0.6.15"; then
      platform_filename="coveralls-linux-x86_64.tar.gz"
    else
      platform_filename="coveralls-linux.tar.gz"
    fi
    ;;
esac

# Attempt to download the Coveralls binary and checksum file
if ! curl -sfLO "https://github.com/coverallsapp/coverage-reporter/releases/${asset_path}/${platform_filename}" ||
   ! curl -sfLO "https://github.com/coverallsapp/coverage-reporter/releases/${asset_path}/coveralls-checksums.txt"; then
  echo "Failed to download coveralls binary or checksum for version: ${COVERAGE_REPORTER_VERSION}."
  echo "This may be due to an invalid version. Please check the available versions at https://github.com/coverallsapp/coverage-reporter/releases."
  [ "${COVERALLS_FAIL_ON_ERROR}" != "1" ] && exit 0
  exit 1
fi

# Verify the downloaded binary:
# The following code was chosen to replace the more simple `sha256sum -c` because it provides
# clearer debugging information re: our matrix of supported coverage-reporter versions and platforms.
# We may drop back to `${platform_filename}" coveralls-checksums.txt | sha256sum -c` when we're more confidently handling these.

# DEBUG: Print contents of checksum file for debugging
echo "Contents of coveralls-checksums.txt:"
cat coveralls-checksums.txt

# Extract expected checksum
expected_checksum=$(grep "${platform_filename}" coveralls-checksums.txt | awk '{print $1}')
if [ -z "$expected_checksum" ]; then
  echo "Failed to extract checksum for ${platform_filename}. This may indicate an invalid version."
  [ "${COVERALLS_FAIL_ON_ERROR}" != "1" ] && exit 0
  exit 1
fi

# Compute actual checksum
actual_checksum=$(sha256sum "${platform_filename}" | awk '{print $1}')

# Perform verification by comparing expected and actual checksums
if [ "$expected_checksum" != "$actual_checksum" ]; then
  echo "Checksum verification failed."
  echo "Expected: $expected_checksum"
  echo "Actual: $actual_checksum"
  [ "${COVERALLS_FAIL_ON_ERROR}" != "1" ] && exit 0
  exit 1
fi

# Extract / install the binary
if ! tar -xzf "${platform_filename}"; then
  echo "Failed to extract coveralls binary."
  [ "${COVERALLS_FAIL_ON_ERROR}" != "1" ] && exit 0
  exit 1
fi

# Check architecture compatibility before attempting any execution
if [ -f ./coveralls ]; then
  SYSTEM_ARCH=$(uname -m)
  # For versions >= v0.6.15, we need to check architecture even when platform isn't specified
  if version_ge "$COVERAGE_REPORTER_VERSION" "v0.6.15"; then
    if [[ -z "${COVERAGE_REPORTER_PLATFORM}" && "${SYSTEM_ARCH}" != "x86_64" ]] || \
       [[ "${COVERAGE_REPORTER_PLATFORM}" == "aarch64" && "${SYSTEM_ARCH}" != "aarch64" ]] || \
       [[ "${COVERAGE_REPORTER_PLATFORM}" == "x86_64" && "${SYSTEM_ARCH}" != "x86_64" ]]; then
      echo "Error: Architecture mismatch. Platform: ${COVERAGE_REPORTER_PLATFORM:-x86_64}, Runner: ${SYSTEM_ARCH}"
      [ "${COVERALLS_FAIL_ON_ERROR}" != "1" ] && exit 0
      exit 1
    fi
  fi
fi

# Ensure the binary exists before attempting to run it
if [ ! -f ./coveralls ]; then
  echo "Coveralls binary not found after extraction."
  [ "${COVERALLS_FAIL_ON_ERROR}" != "1" ] && exit 0
  exit 1
fi

# Output the version of the installed coverage reporter
echo "Installed coverage reporter version: ${COVERAGE_REPORTER_VERSION}"
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
