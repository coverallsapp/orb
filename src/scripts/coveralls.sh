#!/bin/bash

if [ ! "${COVERALLS_REPO_TOKEN}" ]; then
  COVERALLS_REPO_TOKEN=$(printenv "${COVERALLS_REPO_TOKEN_ENV}")
  export COVERALLS_REPO_TOKEN
fi

if "${COVERALLS_DONE}"; then
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

if "${COVERALLS_VERBOSE}"; then
  coveralls --verbose < "${COVERALLS_COVERAGE_FILE}"
else
  coveralls < "${COVERALLS_COVERAGE_FILE}"
fi
