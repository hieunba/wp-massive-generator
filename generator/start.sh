#!/bin/bash
set -eou pipefail

docker_tag="mli/generator"

log() {
  echo "GENERATOR :: INFO :: $1"
}

log_error() {
  echo "GENERATOR :: ERROR :: $1"
  exit 1
}

check_docker() {
  command -v docker >/dev/null || log_error 'Docker was not found'
}

check_image() {
  set -ex; docker inspect $docker_tag > /dev/null || {
    log 'Building Docker image..'
    build_image
  }
}

build_image() {
  set -ex; docker build -t $docker_tag .
}

# __MAIN__
check_docker
check_image
