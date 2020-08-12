#!/bin/bash
set -eou pipefail

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
  set -ex; docker inspect $docker_tag > /dev/null || {
    log_info_msg 'Building Docker image..'
    build_image
  }
}

build_image() {
  set -ex; docker build -t $docker_tag .
}

# __MAIN__
check_docker
check_image
