#!/bin/bash -ex

set -eou pipefail

declare -a pkgs

declare -x WORDPRESS_VERSION="5.5"
declare -x WORDPRESS_SHA1="03fe1a139b3cd987cc588ba95fab2460cba2a89e"

declare -x EFS_MOUNT_DIR="${efs_mount_dir}"
declare -x EFS_MOUNT_TARGET="${efs_mount_target}"

declare -x retries=90

log_info_msg() {
  echo " * $@"
}

log_error_msg() {
  echo " * $@"
  exit 1
}

update_apt() {
  sudo apt-get update -qy
}

install_apache2() {
  command -v apache2ctl || apt-get install -y apache2
}

install_package() {
  local pkg_name="$1"

  result=`dpkg -s $pkg_name || true`

  if [ "$result" ] ; then
    log_info_msg "$pkg_name was installed."
  else
    sudo apt-get install -y $pkg_name
  fi
}

configure_apache2() {
  sudo a2enmod rewrite expires
  sudo a2enmod remoteip
}

reload_apache2() {
  sudo systemctl reload apache2
}

restart_apache2() {
  sudo systemctl restart apache2
}

mount_efs() {
  log_info_msg "Checking if EFS mount directory exists..."

  if [ ! -d $EFS_MOUNT_DIR ] ; then
    log_info_msg "Creating directory $EFS_MOUNT_DIR ..."
    sudo mkdir -p $EFS_MOUNT_DIR || log_error_msg "Directory creation failed!"
  else
    log_info_msg "Directory $EFS_MOUNT_DIR already exists!"
  fi

  if [ ! "`mountpoint -q $EFS_MOUNT_DIR`" ] ; then
    sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "$EFS_MOUNT_TARGET":/ $EFS_MOUNT_DIR || log_error_msg "Failed to mount EFS target"
  else
    log_info_msg "Directory $EFS_MOUNT_DIR is already a valid mountpoint!"
  fi
}

pkgs="apache2 libapache2-mod-php7.4 php7.4-mysql php7.4-cli php7.4-json php7.4-gd \
       php7.4-xml php7.4-imap php7.4-mbstring php7.4-intl \
       php-getid3 php-mail"

update_apt

install_package "nfs-common"

for pkg in $pkgs; do
  install_package $pkg
done

configure_apache2
reload_apache2

while true; do
  if [ "`dig $EFS_MOUNT_TARGET +short`" ] ; then
    break
  fi
  sleep 15
  let retries=$((retries-15))
done

mount_efs

if [ ! "`mountpoint -q /var/www`" ] ; then
  sudo mount -o bind $EFS_MOUNT_DIR /var/www
fi

if [ ! -d /var/www/html ] ; then
  sudo mkdir /var/www/html
  sudo chown -R www-data: /var/www/html
fi

if [ ! -e /var/www/html/index.php ] &&
   [ ! -e /var/www/html/wp-includes/version.php ] &&
   [ ! -e /var/www/html/install.lock ] ; then
  log_info_msg "WordPress not found in /var/www/html - copying now..."
  curl -o wordpress.tar.gz -fSL "https://wordpress.org/wordpress-"$WORDPRESS_VERSION".tar.gz"
  echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c -
  sudo tar xzf wordpress.tar.gz --strip-components=1 -C /var/www/html
  rm wordpress.tar.gz

  sudo chown -R www-data: /var/www/html/
  log_info_msg "WordPress copied..."
fi
