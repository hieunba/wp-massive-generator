#!/bin/bash
set -eou pipefail

declare ENV=
docker_tag=mli/generator

banner() {
  echo -n " * "
}

log_info_msg() {
  banner
  echo "$@"
}

log_success_msg() {
  local GREEN=`tput setaf 3`
  local NORMAL=`tput op`
  echo " $GREEN*$NORMAL $@"
  exit 0
}

log_error_msg() {
  local RED=`tput setaf 1`
  local NORMAL=`tput op`
  echo " $RED*$NORMAL $@"
  exit 1
}

check_docker() {
  command -v docker >/dev/null || log_error_msg 'Docker was not found'
}

check_image() {
    docker inspect $docker_tag > /dev/null || {
    log_info_msg 'Building Docker image..'
    build_image
  }
}

build_image() {
    if [ "x${ENV,,}" == "xdev" ] ; then
        local BUILD_OPTIONS="--rm"
    else
        local BUILD_OPTIONS="--quiet --rm"
    fi
    docker build $BUILD_OPTIONS -t $docker_tag .
}

# __MAIN__
check_docker
check_image
