#!/bin/bash
set -euo pipefail

if [ "$AWS_DEFAULT_REGION" ] ; then
  export TF_VAR_region=$AWS_DEFAULT_REGION
fi

exec "$@"
