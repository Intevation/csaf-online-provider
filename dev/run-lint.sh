#!/bin/bash

# Executes all linters. Should errors occur, CATCH will be set to 1, causing an erroneous exit code.

echo "########################################################################"
echo "###################### Run Linters #####################################"
echo "########################################################################"

# Parameters
while getopts "lscp" FLAG; do
    case "${FLAG}" in
    l) LOCAL=true ;;
    *) echo "Can't parse flag ${FLAG}" && break ;;
    esac
done

# Setup

DC="docker compose -f docker-compose.yml"
PATHS="backend/src/"

# Safe Exit
trap 'if [ -z "$LOCAL" ]; then docker compose -f docker-compose.test.yml down; fi' EXIT

# Execution
if [ -z "$LOCAL" ]
then
    # Setup
    make dev

    # Container Mode
    eval "$DC exec black --check --diff ${PATHS}"
    eval "$DC exec isort --check-only --diff ${PATHS}"
    eval "$DC exec flake8 ${PATHS}"
    eval "$DC exec mypy -m ${PATHS}"

else
    # Local Mode
    black --diff ${PATHS}
    isort --diff ${PATHS}
    flake8 ${PATHS}
    mypy -m ${PATHS}
fi
