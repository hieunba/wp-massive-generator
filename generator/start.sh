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
  EC2_INSTANCE_NO="${EC2_INSTANCE_NO:-1}"
  EC2_KEYPAIR="${EC2_KEYPAIR:-mli}"
  WP_HAS_CDN="${WP_HAS_CDN:-false}"
  WP_HAS_LB="${WP_HAS_LB:-false}"
  WP_SITEURL="${WP_SITEURL:-}"
  WP_HOME="${WP_HOME:-}"

  log_info_msg "Defaults values"
  if [ "x${ENV,,}" == "xdebug" ] ; then
    typeset -p AWS_ACCESS_KEY_ID \
               AWS_SECRET_ACCESS_KEY
  fi

  typeset -p AWS_DEFAULT_REGION \
             EC2_INSTANCE_TYPE \
	     EC2_INSTANCE_NO \
             EC2_KEYPAIR \
             WP_HAS_CDN \
             WP_HAS_LB \
             WP_SITEURL \
             WP_HOME
}

validate_region() {
    if [[ ! $1 =~ [a-z]+-[a-z]+-[0-9]$ ]] ; then
       log_error_msg "Region was invalid: ${1}"
    fi
}

validate_instance_no() {
  if [[ ! $1 =~ [0-9]+$ ]] ; then
    log_error_msg "Selected number of instances was invalid: ${1}"
  fi
}

validate_instance_type() {
    if [[ ! $1 =~ [tamcrpgifdh][1-5][a-z]?\.[a-z]+$ ]] ; then
       log_error_msg "Select instance type was invalid: ${1}"
    fi
}

check_parameters() {
  if [ -z "${1:-}" ] ; then
    log_error_msg "Requires additional input"
  elif [ "${1:0:1}" = "-" ] ; then
    log_error_msg "Invalid argument: ${1}"
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
		 --env EC2_INSTANCE_NO=$EC2_INSTANCE_NO \
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
}

# __MAIN__
load_defaults

while (( "$#" )) ; do
  case $1 in
    --access-key|--key|-k)
      shift 1
      check_parameters "$1"
      AWS_ACCESS_KEY_ID="$1"
      ;;
    --secret-key|--secret|-s)
      shift 1
      check_parameters "$1"
      AWS_SECRET_ACCESS_KEY="$1"
      ;;
    --region|-r)
      shift 1
      check_parameters "$1"
      validate_region "$1"
      AWS_DEFAULT_REGION="$1"
      ;;
    --instance-type|-t)
      shift 1
      check_parameters "$1"
      validate_instance_type "$1"
      EC2_INSTANCE_TYPE="$1"
      ;;
    --instance-no|-n)
      shift 1
      check_parameters "$1"
      validate_instance_no "$1"
      EC2_INSTANCE_NO="$1"
      ;;
    --siteurl|--url)
      shift 1
      check_parameters "$1"
      WP_SITEURL="$1"
      ;;
    *)
      log_error_msg "Unknown parameter: ${1}"
      ;;
  esac
  shift 1
done

check_docker

log_info_msg 'Building Docker image..'
build_image

mli_container_id=$(create_container) || log_error_msg "Could not create a Docker container"

start_deployment $mli_container_id || error_code=$?

declare rc=${error_code:-}

log_info_msg "Cleaning up Docker environment."
clean_docker $mli_container_id

if [ $rc ] ; then
  log_error_msg "Deployment failed"
else
  log_success_msg "Deployment completed successfully."
fi

