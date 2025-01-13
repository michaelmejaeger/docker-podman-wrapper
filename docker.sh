#!/usr/bin/env bash
#
# Replaces docker with podman.
# In order to make it work, you have to do the following
# - Copy the script to a directory in the path and rename it to `docker` (e.g. "cp docker.sh $HOME/bin/docker")
# - Install Podman (e.g. `brew install podman`)
# - On MacOS: Start Podman with `podman-machine-start`
# - Set the variable DOCKER_HOST to: `podman-dockerhost` (on Linux: `export DOCKER_HOST=unix://$(podman info --format '{{.Host.RemoteSocket.Path}}')`)
# - Start the Podman API-Service: `mkdir -p "$(dirname "${DOCKER_HOST#unix://}")" & podman system service --time 0 "$DOCKER_HOST" &`

# if [ -n "${DEBUG}" ]; then
#   set -o xtrace
# fi
set -o errexit # script stops on error (RC != 0)
# set -o nounset  # abort on using undefined variable
set -o pipefail # script fails of one of the commands in the pipeline fails

# DEBUG="x" # Set to a value to output debug messages
DRYRUN="" # Set to a value to create dry run

##############################################################################
# FUNCTIONS
##############################################################################

log() {
  if [ "$1" = "-n" ]; then
    shift
    echo -n -e "$1$2$"
  else
    echo -e "$1$2$"
  fi
}

# For debugging
log_debug() {
  if [ -n "$DEBUG" ]; then
    log "" "[DCKR] $1"
  fi
}

##############################################################################
# MAIN
##############################################################################
log_debug "== START OF DOCKER WRAPPER (cwd: $PWD) ========================================="
log_debug "Got arguments: ${*}"

if [ -z "$3" ]; then
  log_debug "Calling plain: podman $*"
  log_debug "v-------------------------------------------------------------------------------"
  if [ -z "$DRYRUN" ]; then
    podman "$@"
    log_debug "^-------------------------------------------------------------------------------"
  fi
elif [ "$3" = "buildx" ]; then
  shift 3
  declare -a PARAMS=()
  PARAMNAME=""
  TAG=""
  CONTAINERNAME=""
  REGISTRY=""
  VERSIONTAG=""
  MANIFEST=""
  PUSH=0
  for p in "$@"; do
    if [ "$p" = "--builder" ] || [ "$PARAMNAME" = "--builder" ]; then
      log_debug "Omitting parameter --builder!"
    elif [ "$PARAMNAME" = "--tag" ]; then
      TAG="$p"
      CONTAINERNAME="$(echo "$TAG" | cut -f 2 -d "/" | cut -f 1 -d ":")"
      REGISTRY="$(echo "$TAG" | cut -f 1 -d "/" -s)"
      VERSIONTAG="$(echo "$TAG" | cut -f 2 -d "/" | cut -f 2 -d ":")"
      MANIFEST="$CONTAINERNAME"
      # PARAMS+=("$p")
    elif [ "$p" = "--tag" ]; then
      TAG=""
    elif [ "$p" = "--push" ]; then
      PUSH=1
    else
      PARAMS+=("$p")
    fi
    PARAMNAME="$p"
  done

  if [ -n "$TAG" ]; then
    if podman manifest exists "$MANIFEST" >/dev/null 2>&1; then
      ARGS=("manifest" "rm" "$MANIFEST")
      log_debug "Removing manifest for buildx: podman ${ARGS[*]}"
      log_debug "v-------------------------------------------------------------------------------"
      if [ -z "$DRYRUN" ]; then
        podman "${ARGS[@]}"
        log_debug "^-------------------------------------------------------------------------------"
      fi
    fi
    ARGS=("manifest" "create" "$MANIFEST")
    log_debug "Creating manifest for buildx: podman ${ARGS[*]}"
    log_debug "v-------------------------------------------------------------------------------"
    if [ -z "$DRYRUN" ]; then
      podman "${ARGS[@]}"
      log_debug "^-------------------------------------------------------------------------------"
    fi
  fi

  # shellcheck disable=SC2198
  if [ "${PARAMS[@]:0:1}" = "build" ]; then
    PARAMS=("build" "--network=host" "${PARAMS[@]:1}")
  fi

  if [ $PUSH -eq 1 ] && [ -n "$TAG" ]; then
    PARAMS_C=("${PARAMS[@]:0:${#PARAMS[@]}-1}")
    ARGS=("${PARAMS_C[@]}" "--manifest" "$MANIFEST" "${PARAMS[-1]}")
    log_debug "Calling for buildx/push: podman ${ARGS[*]}"
    log_debug "v-------------------------------------------------------------------------------"
    if [ -z "$DRYRUN" ]; then
      podman "${ARGS[@]}"
      log_debug "^-------------------------------------------------------------------------------"
    fi

    ARGS=("manifest" "push" "$MANIFEST" "docker://$REGISTRY/$CONTAINERNAME:$VERSIONTAG")
    log_debug "Calling for buildx/push: podman ${ARGS[*]}"
    log_debug "v-------------------------------------------------------------------------------"
    if [ -z "$DRYRUN" ]; then
      podman "${ARGS[@]}"
      log_debug "^-------------------------------------------------------------------------------"
    fi
  else
    if [ "${PARAMS[0]}" = "create" ] || [ "${PARAMS[0]}" = "ls" ]; then
      log_debug "Omitting call for buildx: podman ${PARAMS[*]}"
    else
      log_debug "Calling for buildx: podman ${PARAMS[*]}"
      log_debug "v-------------------------------------------------------------------------------"
      if [ -z "$DRYRUN" ]; then
        podman "${PARAMS[@]}"
        log_debug "^-------------------------------------------------------------------------------"
      fi
    fi
  fi
else
  log_debug "Calling: podman $*"
  log_debug "v-------------------------------------------------------------------------------"
  if [ -z "$DRYRUN" ]; then
    podman "$@"
    log_debug "^-------------------------------------------------------------------------------"
  fi
fi
log_debug "== END OF DOCKER WRAPPER ======================================================="
