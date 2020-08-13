#!/bin/bash
set -eou pipefail

declare ENV=${ENV:-}
declare mli_container_id=
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

  if [ "x${ENV,,}" == "xdebug" ] ; then
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

build_image() {
    if [ "x${ENV,,}" == "xdebug" ] ; then
        local BUILD_OPTIONS="--rm"
    else
        local BUILD_OPTIONS="--quiet --rm"
    fi
    docker build $BUILD_OPTIONS -t $docker_tag .
}

create_container() {
  local mli_container_id=

  if [ "x${ENV,,}" == "xdebug" ] ; then
    set -ex;
  fi
  docker create -it \
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
                 $docker_tag
}

start_deployment() {
  local id="$1"
  if [ "x${ENV,,}" == "xdebug" ] ; then
    set -ex;
  fi
  docker start -i -a $id
}

stop_container() {
  local id="$1"
  docker stop $id
}

remove_container() {
  local id="$1"
  docker rm $id
}

clean_docker() {
  local id="$1"
  if [ "x${ENV,,}" == "xdebug" ] ; then
    set -ex;
  fi
  stop_container $id
  remove_container $id
}

# __MAIN__
load_defaults

check_docker

log_info_msg 'Building Docker image..'
build_image

mli_container_id=$(create_container) || log_error_msg "Could not create a Docker container"

start_deployment $mli_container_id || error_code=$?

if [ $error_code ] ; then
  log_error_msg "Deployment failed"
else
  log_info_msg "Cleaning up Docker environment."

  clean_docker $mli_container_id

  log_success_msg "Deployment completed successfully."
fi
