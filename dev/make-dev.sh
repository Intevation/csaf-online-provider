#!/bin/bash

# Import utils package
. "$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/util.sh"

# Processes various development operations

# Functions
help ()
{
    info "\
Builds and starts development related images.

Parameters:
    #1 TARGET       : Name of the makefile target that called this script
    #2 FLAGS        : Optional Flags (see below)
    #3 ARGS         : Additional parameters that will be appended to the called docker run or docker compose calls

Flags:
    no-cache        : Prevents use of cache when building docker images
    capsule         : Enables encapsulation of docker build output

Available dev functions:
    dev             : Builds and starts development images
    dev-help        : Print help
    dev-detached    : Builds and starts development images with detach flag. This causes started container to run in the background
    dev-attached    : Builds and starts development images; enters shell of started image. The \$ARGS parameter determines
                          the specific container id you will enter (default value is equal the service name)
    dev-standalone  : Builds and starts development images; closes them immediately afterwards
    dev-stop        : Stops any currently running images associated with the service or docker compose file
    dev-exec        : Executes command inside container.
                          Use \$ARGS to declare command that should be used and declare which container the command should be used in.
    dev-enter       : Enters shell of started container. The \$ARGS parameter determines
                          the specific container id you will enter (default value is equal the service name)
    dev-build       : Builds the development image
    "
}

build_capsuled()
{
    local FUNC=$1

    # Record time
    PRE_TIMESTAMP=$(date +%s)
    local PRE_TIMESTAMP

    # Build Image
    info "Building image"
    capsule "$FUNC"
    local RESPONSE=$?

    POST_TIMESTAMP=$(date +%s)
    local POST_TIMESTAMP

    local BUILD_TIME=$(( POST_TIMESTAMP - PRE_TIMESTAMP ))
    # Output
    if [ "$RESPONSE" != 0 ]
    then
        error "Building image failed: $ERROR"
    elif [ "$BUILD_TIME" -le 3 ]
    then
        success "Image found in cache"
    else
        success "Build image successfully"
    fi
}

build()
{
    local BUILD_ARGS="";

    if [ -n "$NO_CACHE" ]; then local BUILD_ARGS="--no-cache"; fi

    # Build all submodules
    if [ -n "$CAPSULE" ]
    then
        build_capsuled "docker compose build $BUILD_ARGS"
    else
        docker compose build $BUILD_ARGS
    fi
}

clean()
{
    info "Stopping containers"
    if [ "$(docker ps -aq)" = "" ]
    then
        info "No containers to stop"
    else
        docker stop "$(docker ps -aq)"
    fi

    info "Removing containers"
    if [ "$(docker ps -a -q)" = "" ]
    then
        info "No containers to remove"
    else
        docker rm "$(docker ps -a -q)"
    fi

    ask n "Do you want to delete ALL images as well?" || abort 0
    info "Removing images"
    if [ "$(docker images -aq)" = "" ]
    then
        info "No images to remove"
    else
        docker rmi -f "$(docker images -aq)"
    fi
}

run()
{
    info "Running container"
    local FLAGS=$1

    # Compose
    echocmd eval "$DC up $FLAGS $VOLUMES $ARGS"
}

attach()
{
    local TARGET_CONTAINER=$1
    info "Attaching to running container"

    # Determine container to enter, in case no container was specified as a paramater
    if [ -z "$SERVICE" ] && [ -z "$TARGET_CONTAINER" ]
    then
        # Main repository case, use input prompt to determine container
        TARGET_CONTAINER=$(input "Which service container should be entered?");
        local TARGET_CONTAINER
        { [ -z "$TARGET_CONTAINER" ] && \info "No service container declared, exiting" && return; }
    else
        # Submodule case
        { [ -z "$TARGET_CONTAINER" ] && \info "No container was specified; Service container will be taken as default" && local TARGET_CONTAINER="$SERVICE"; }
    fi

    echocmd eval "$DC exec $TARGET_CONTAINER $USED_SHELL"


    local CONTAINER_STATUS="$?"
    if [ "$CONTAINER_STATUS" != 0 ]; then warn "Container exit status: $CONTAINER_STATUS"; fi
}

exec()
{
    local FUNC=$1

    # Compose
    echocmd eval "$DC exec $FUNC"
}

stop()
{
    info "Stop running container"

    # Compose
    echocmd eval "$DC down $CLOSE_VOLUMES"
}

# Setup
## Parameters
TARGET=$1
FLAGS=$2
ARGS=$3

# SERVICE contains all additionally provided make targets. This may include flags
# Extract flags here
TEMP_SERVICE=$FLAGS
for CMD in $TEMP_SERVICE; do
    case "$CMD" in
        "no-cache")     NO_CACHE=true ;;
        "capsule")      CAPSULE=true ;;
        *)              FLAGS="$CMD" ;;
    esac
done

# Variables
LOCAL_PWD=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
USED_SHELL="sh"
COMPOSE_FILE="${LOCAL_PWD}/../docker-compose.yml"

# Strip 'dev', '-' and any '.o' or similar file endings that may have been automatically added from implicit rules by GNU
FUNCTION=${TARGET#"dev"}
FUNCTION=${FUNCTION#"-"}
FUNCTION=${FUNCTION%.*}

if [ -n "$SERVICE" ]; then info "Running $FUNCTION for $SERVICE"
else info "Running $FUNCTION"; fi

# Helpers
USER_ID=$(id -u)
GROUP_ID=$(id -g)
DC="CONTEXT=dev USER_ID=$USER_ID GROUP_ID=$GROUP_ID docker compose -f ${COMPOSE_FILE}"

# - Run specific function
case "$FUNCTION" in
    "help")             help ;;
    "clean")            clean ;;
    "standalone")       build && run && stop ;;
    "detached")         build && run "-d" && info "Containers started" ;;
    "attached")         build && run "-d" && attach "$ARGS" && stop ;;
    "stop")             stop ;;
    "exec")             exec "$ARGS" ;;
    "enter")            attach "$ARGS" ;;
    "build")            build ;;
    "")                 build && run ;;
    *)                  warn "No command found matching $FUNCTION" && help ;;
esac

exit $?
