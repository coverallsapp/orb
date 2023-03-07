#!/bin/bash

if [ ! "${COVERALLS_REPO_TOKEN}" ]; then
  COVERALLS_REPO_TOKEN=$(printenv "${COVERALLS_REPO_TOKEN_ENV}") || (echo "Token not configured" && exit 1)
  export COVERALLS_REPO_TOKEN
fi

if [ "${COVERALLS_DONE}" == "1" ]; then
  echo "Sending parallel finish webhook"

  [ "${COVERALLS_DRY_RUN}" == "1" ] && exit 0

  curl "${COVERALLS_ENDPOINT}/webhook?repo_token=${COVERALLS_REPO_TOKEN}&carryforward=${COVERALLS_CARRYFORWARD_FLAGS}" \
    -d "payload[build_num]=${CIRCLE_WORKFLOW_ID}&payload[status]=done"

  exit 0
fi

if [[ $EUID == 0 ]]; then
  export SUDO=""
else
  export SUDO="sudo"
fi

$SUDO npm install -g coveralls

# check for lcov file presence:
if [ ! -r "${COVERALLS_COVERAGE_FILE}" ]; then
  echo "Please specify a valid 'path_to_lcov' parameter."
  exit 1
fi

echo "Processing coverage from ${COVERALLS_COVERAGE_FILE}"

[ "${COVERALLS_DRY_RUN}" == "1" ] && exit 0

if [ "${COVERALLS_VERBOSE}" == "1" ]; then
  coveralls --verbose < "${COVERALLS_COVERAGE_FILE}"
else
  coveralls < "${COVERALLS_COVERAGE_FILE}"
fi
