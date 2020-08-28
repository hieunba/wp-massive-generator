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

init_deployment() {
  terraform init
}

cleanup_deployment() {
  local PROVISIONER_PATH="./scripts/bootstrap/provisioner.sh"

  if [ ! -e $PROVISIONER_PATH ] ; then
    touch $PROVISIONER_PATH && echo '#!/bin/bash' > $PROVISIONER_PATH
  fi

  terraform destroy -auto-approve
}

validate_deployment() {
  local PROVISIONER_PATH="./scripts/bootstrap/provisioner.sh"

  if [ ! -e $PROVISIONER_PATH ] ; then
    touch $PROVISIONER_PATH && echo '#!/bin/bash' > $PROVISIONER_PATH
  fi

  terraform validate && rm $PROVISIONER_PATH
}

# _MAIN_

AWS_VERIFY_RESULT="$(get_account_id)"

if [[ $AWS_VERIFY_RESULT =~ ^[0-9]+$ ]] ; then
  log_info_msg "Valid AWS Access Keys validated!"
else
  log_error_msg $AWS_VERIFY_RESULT
fi

init_deployment

validate_deployment

if [ $? -ne 0 ] ; then
  log_error_msg "Failed to validate the Terraform plan"
fi

terraform apply -target=local_file.provisioner -auto-approve

terraform apply -auto-approve

if [ $? -ne 0 ] ; then
  log_info_msg "Something went wrong"
  log_info_msg "Cleaning up deployed resources..."

  cleanup_deployment

  if [ $? -eq 0 ] ; then
    log_error_msg "Deployed resources cleaned up."
  else
    log_error_msg "Failed to destroy the pending resources. Please clean up them manually"
  fi
fi
