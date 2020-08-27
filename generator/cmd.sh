#!/bin/bash

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

get_account_id() {
  aws sts get-caller-identity --query "Account" --output text
}

# _MAIN_

AWS_VERIFY_RESULT="$(get_account_id)"

if [[ $AWS_VERIFY_RESULT =~ ^[0-9]+$ ]] ; then
  log_info_msg "Valid AWS Access Keys validated!"
else
  log_error_msg $AWS_VERIFY_RESULT
fi
