#!/bin/bash
set -eou pipefail

declare ENV=${ENV:-}
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

load_defaults() {
  AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-west-2}"
  AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
  AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
  EC2_INSTANCE_TYPE="${EC2_INSTANCE_TYPE:-t2.small}"
  EC2_KEYPAIR="${EC2_KEYPAIR:-mli}"
  WP_HAS_CDN="${WP_HAS_CDN:-false}"
  WP_HAS_LB="${WP_HAS_LB:-false}"
  WP_SITEURL="${WP_SITEURL:-}"
  WP_HOME="${WP_HOME:-}"

  if [ "x${ENV,,}" == "xdev" ] ; then
    log_info_msg "Defaults values"
    typeset -p AWS_DEFAULT_REGION \
               AWS_ACCESS_KEY_ID \
               AWS_SECRET_ACCESS_KEY \
               EC2_INSTANCE_TYPE \
               EC2_KEYPAIR \
               WP_HAS_CDN \
               WP_HAS_LB \
               WP_SITEURL \
               WP_HOME
  fi
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

create_container() {
  local mli_container_id=

  if [ "x${ENV,,}" == "xdev" ] ; then
    set -ex;
  fi
  mli_container_id=$(docker create -it \
                     --env ENV=$ENV \
                     --env AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
                     --env AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
                     --env AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION \
                     --env EC2_INSTANCE_TYPE=$EC2_INSTANCE_TYPE \
                     --env EC2_KEYPAIR=$EC2_KEYPAIR \
                     --env WP_HAS_CDN=$WP_HAS_CDN \
                     --env WP_HAS_LB=$WP_HAS_LB \
                     --env WP_SITEURL=$WP_SITEURL \
                     --env WP_HOME=$WP_HOME \
                     $docker_tag)
  return $mli_container_id
}

# __MAIN__
load_defaults
check_docker
check_image
create_container
