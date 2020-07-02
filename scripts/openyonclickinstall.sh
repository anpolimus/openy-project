#!/bin/bash
# To get the latest stable OpenY on DigitalOcean 16.04 LST x64 droplet run the command:
#   curl -Ls http://bit.ly/initopeny | bash -s
#   or
#   curl -Ls http://bit.ly/initopeny | bash -s stable
# To get the latest dev:
#   curl -Ls http://bit.ly/initopeny | bash -s dev
# To get the latest beta:
#   curl -Ls http://bit.ly/initopeny | bash -s beta
# To get a particular version:
#   curl -Ls http://bit.ly/initopeny | bash -s 8.1.10
# To get a particular branch:
#   curl -Ls http://bit.ly/initopeny | bash -s dev-BRANCH_NAME
# as root user
#
# To get Virtual Y
#   curl -Ls https://openy.org/l/virtualy | bash -s virtualy
#

OPENYBETA="8.2.*@beta"
OPENYDEV="dev-8.x-2.x"

OPENYVERSION="$1"
OPENYVERSION=${OPENYVERSION:-stable}

# Set up locale if it's missed
[ -z "$LC_ALL" ] && export LC_ALL=en_US.UTF-8
[ -z "$LANGUAGE" ] && export LANGUAGE=en_US.UTF-8
[ -z "$LC_CTYPE" ] && export LC_TYPE=en_US.UTF-8
[ -z "$LANG" ] && export LANG=en_US.UTF-8

printf "Hello, OpenY evaluator.\n OpenY one click install version 1.6.\n"

printf "Installing OpenY into /var/www/html\n"

printf "\nMaking backup of existing /var/www/html folder to /var/www/html.bak\n"
sudo rm -rf /var/www/html.bak/html || true
sudo mv /var/www/html /var/www/html.bak || true

printf "\nInstalling mysql server\n"
sudo apt-get -y update || true

root_pass="root"

sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password root'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password root'
sudo apt-get -y install mysql-server

sudo mysql -uroot -p$root_pass -e "drop database drupal;" || true
sudo mysql -uroot -p$root_pass -e "create database drupal;" || true
sudo mkdir -p /var/www || true
cd /var/www
sudo rm -rf cibox || true
git clone --branch=ansible_lamp https://github.com/cibox/cibox.git
cd cibox
bash core/cibox-project-builder/files/vagrant/box/provisioning/shell/initial-setup.sh core/cibox-project-builder/files/vagrant/box/provisioning
bash core/cibox-project-builder/files/vagrant/box/provisioning/shell/ansible.sh
sh cilamp.sh
sudo sed -i "s/var\/www/var\/www\/html\/docroot/g" /etc/apache2/sites-enabled/vhosts.conf

sudo service apache2 restart

drush dl -y drupal-8.9.x --dev --destination=/tmp --default-major=8 --drupal-project-rename=drupal

cd /tmp/drupal
drush si -y minimal --db-url=mysql://root:$root_pass@localhost/drupal ; drush sql-drop -y
drush sql-drop -y

printf "\nPreparing OpenY code tree \n"
sudo rm -rf /var/www/html.bak/html || true
sudo mv /var/www/html /var/www/html.bak || true
COMPOSER_MEMORY_LIMIT=-1 composer create-project ymcatwincities/openy-project:8.2.x-dev /var/www/html --no-interaction -v --profile
cd /var/www/html/

IP="$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')"

# Check if the Open Y version must be adjusted.
if [[ "$OPENYVERSION" == "stable" ]]; then
  echo "Installing Latest Stable Open Y"
elif [[ "$OPENYVERSION" == "dev" ]]; then
  echo "Installing Latest Dev Open Y"
  COMPOSER_MEMORY_LIMIT=-1 composer remove ymcatwincities/openy --no-update
  COMPOSER_MEMORY_LIMIT=-1 composer require ymcatwincities/openy:${OPENYDEV} --update-with-dependencies
  COMPOSER_MEMORY_LIMIT=-1 composer update
  cp /tmp/drupal/sites/default/settings.php /var/www/html/docroot/sites/default/settings.php
  sudo mkdir /var/www/html/docroot/sites/default/files
  echo "\$config['system.logging']['error_level'] = 'hide';" >> /var/www/html/docroot/sites/default/settings.php
  sudo chmod -R 777 /var/www/html/docroot/sites/default/settings.php
  sudo chmod -R 777 /var/www/html/docroot/sites/default/files

  printf "\nOpen http://$IP/core/install.php to proceed with Open Y installation.\n"
elif [[ "$OPENYVERSION" == "virtualy" ]]; then
  echo "Installing Latest Standalone Virtual Y"
  COMPOSER_MEMORY_LIMIT=-1 composer require ymcatwincities/openy_gated_content  -v --profile
  COMPOSER_MEMORY_LIMIT=-1 composer update  -v --profile
  cd /var/www/html/docroot
  ansible-playbook /var/www/html/vendor/ymcatwincities/openy-cibox-vm/cibox/jobs/build.yml  -i 'localhost,' --connection=local -e "server_docroot_folder=/var/www/html workspace=/var/www/html/ build_number=docroot build_folder_prefix="
  cd /
  cd /var/www/html/docroot
  ls
  ansible-playbook -vvvv /var/www/html/vendor/ymcatwincities/openy-cibox-build/reinstall.yml  -i 'localhost,' --connection=local -e "php_env_vars='cd /var/www/html/docroot && APP_ENV=dev' use_solr=false platform_settings_file=/var/www/html/docroot/sites/default/settings.php mysql_user=root mysql_password=root mysql_db=virtualy drupal_folder=/var/www/html/docroot site_url=$IP pp_environment=virtual_y run_reinstall=true openy_profile_install_settings='openy_configure_profile.preset=standard openy_theme_select.theme=openy_carnation openy_select_content.content=0' sites_default_file_path=/var/www/html/docroot/sites/example.sites.php solr_module_config_path=/var/www/html/docroot/modules/contrib/search_api_solr/solr-conf/4.x"
  sudo chmod a+w /var/www/html/docroot/sites/default/files
  sudo chown -R www-data:www-data /var/www/html/docroot/
  drush cr 
  
  printf "\n\n\n\n\n Open http://$IP/ to view Virtual Y installation.\n\n\n Open link below to login as admin user. Change password after login!\n\n\n\n"
  drush uli -l http://$IP/
  printf "\n\n\n Open http://$IP/user/1/edit to change your password.\n"
  
elif [[ "$OPENYVERSION" == "beta" ]]; then
  echo "Installing Latest Beta Open Y"
  COMPOSER_MEMORY_LIMIT=-1 composer remove ymcatwincities/openy --no-update
  COMPOSER_MEMORY_LIMIT=-1 composer require ymcatwincities/openy:${OPENYBETA} --update-with-dependencies
  COMPOSER_MEMORY_LIMIT=-1 composer update
  cp /tmp/drupal/sites/default/settings.php /var/www/html/docroot/sites/default/settings.php
  sudo mkdir /var/www/html/docroot/sites/default/files
  echo "\$config['system.logging']['error_level'] = 'hide';" >> /var/www/html/docroot/sites/default/settings.php
  sudo chmod -R 777 /var/www/html/docroot/sites/default/settings.php
  sudo chmod -R 777 /var/www/html/docroot/sites/default/files

  printf "\nOpen http://$IP/core/install.php to proceed with Open Y installation.\n"
else
  echo "Installing Open Y $OPENYVERSION"
  COMPOSER_MEMORY_LIMIT=-1 composer remove ymcatwincities/openy --no-update
  COMPOSER_MEMORY_LIMIT=-1 composer require ymcatwincities/openy:${OPENYVERSION} --update-with-dependencies
  COMPOSER_MEMORY_LIMIT=-1 composer update
  cp /tmp/drupal/sites/default/settings.php /var/www/html/docroot/sites/default/settings.php
  sudo mkdir /var/www/html/docroot/sites/default/files
  echo "\$config['system.logging']['error_level'] = 'hide';" >> /var/www/html/docroot/sites/default/settings.php
  sudo chmod -R 777 /var/www/html/docroot/sites/default/settings.php
  sudo chmod -R 777 /var/www/html/docroot/sites/default/files

  printf "\nOpen http://$IP/core/install.php to proceed with Open Y installation.\n"
fi




