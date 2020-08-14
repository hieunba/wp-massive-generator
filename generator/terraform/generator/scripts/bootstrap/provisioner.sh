#!/bin/bash -ex

set -eou pipefail

declare -a pkgs

declare -x WORDPRESS_VERSION="5.5"
declare -x WORDPRESS_SHA1="03fe1a139b3cd987cc588ba95fab2460cba2a89e"

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

configure_apache2() {
  sudo a2enmod rewrite expires
  sudo a2enmod remoteip
}

pkgs=(apache2 libapache2-mod-php7.4 php7.4-mysql php7.4-cli php7.4-json)

update_apt

for pkg in ${pkgs[@]}; do
  install_package $pkg
done

configure_apache2

[ -f /var/www/html/index.html ] && sudo rm -f /var/www/html/index.html

if [ ! -e /var/www/html/index.php ] && [ ! -e /var/www/html/wp-includes/version.php ] ; then
  echo "WordPress not found in /var/www/html - copying now..."
  curl -o wordpress.tar.gz -fSL "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz"
  echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c -
  sudo tar xzf wordpress.tar.gz --strip-components=1 -C /var/www/html
  rm wordpress.tar.gz

  sudo chown -R www-data: /var/www/html/
fi
