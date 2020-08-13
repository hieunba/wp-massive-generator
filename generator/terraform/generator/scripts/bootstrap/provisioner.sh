#!/bin/bash -ex

set -eou pipefail

declare -a pkgs

log_info_msg() {
  echo " * $@"
}

update_apt() {
  sudo apt-get update -qy
}

install_apache2() {
  command -v apache2ctl || apt-get install -y apache2
}

install_package() {
  local pkg_name="$1"

  result=$(dpkg -s ${pkg_name} || true)

  if [ "$result" ] ; then
    log_info_msg "${pkg_name} was installed."
  else
    sudo apt-get install -y $pkg_name
  fi
}

pkgs=(apache2 libapache2-mod-php7.4 php7.4-mysql php7.4-cli php7.4-json)

update_apt

for pkg in ${pkgs[@]}; do
  install_package $pkg
done
