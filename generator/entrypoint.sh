#!/bin/bash
set -euo pipefail

if [ "$AWS_DEFAULT_REGION" ] ; then
  export TF_VAR_region=$AWS_DEFAULT_REGION
fi
export TF_VAR_wp_siteurl=$WP_SITEURL
export TF_VAR_instance_type=$EC2_INSTANCE_TYPE
export TF_VAR_autoscale_min_size=$EC2_INSTANCE_NO

exec "$@"
