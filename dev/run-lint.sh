#!/bin/bash

. "$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/util.sh"

# Executes all linters. Should errors occur, CATCH will be set to 1, causing an erroneous exit code.

shout "Run Linters"

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
    info "Building and running dev container"

    # Setup
    echocmd make dev

    info "Linting"
    # Container Mode
    echocmd eval "$DC exec black --check --diff ${PATHS}"
    echocmd eval "$DC exec isort --check-only --diff ${PATHS}"
    echocmd eval "$DC exec flake8 ${PATHS}"
    echocmd eval "$DC exec mypy -m ${PATHS}"

else
    # Local Mode
    echocmd black --diff ${PATHS}
    echocmd isort --diff ${PATHS}
    echocmd flake8 ${PATHS}
    echocmd mypy -m ${PATHS}
fi
