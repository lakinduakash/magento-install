#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Config

MAGENTO_SYSTEM_USER=magento
MAGENTO_SYSTEM_PASSWORD=magento@123

MAGENTO_ADMIN_USERNAME=admin
MAGENTO_ADMIN_EMAIL=admin@admin.com
MAGENTO_ADMIN_PASSWORD=admin@123

MAGENTO_DATABASE=magento
MAGENTO_DATABASE_USERNAME=magentip
MAGENTO_DATABASE_PASSWORD=magento@123

SITE_NAME=mydomain

# VERSIONS

MAGENTO_VERSION=2.2
MYSQL_VERSION=5.7.* # Install seperatly
PHP_VERSION=7.1
ELASTICSEARCH_VERSION=7.13.*
APACHE_VERSION=2.*
COMPOSER_VERSION=1.4.1

# JAVA_VERSION=8

# Magento installation directory

# MAGENTO_DIR=/var/www/html/${SITE_NAME}
MAGENTO_DIR=/home/${MAGENTO_SYSTEM_USER}/${SITE_NAME}

### Start installation

apt-get update -q

sudo add-apt-repository ppa:ondrej/php

# Install 
sudo apt-get install -yq \
    apt-transport-https \
    openjdk-8-jdk \
    mysql-server=${MYSQL_VERSION} \
    php${PHP_VERSION} \
    apache2=${APACHE_VERSION} \
    libapache2-mod-php${PHP_VERSION} \
    php${PHP_VERSION}-mysql \
	zip \
	unzip

# Install php extensions

apt-get install -yq php${PHP_VERSION}-{mysql,mcrypt,gd,curl,intl,bcmath,ctype,dom,iconv,mbstring,simplexml,soap,xsl,zip}

# Install elasticsearch

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -

echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list

apt-get update && apt-get install -yq elasticsearch=${ELASTICSEARCH_VERSION}


# Start elasticsearch

systemctl enable elasticsearch
systemctl start elasticsearch


# Install composer

php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '756890a4488ce9024fc62c56153228907f1545c228516cbf63f885e036d37e9a59d27d63f46af1d4d07ee0f76181c7d3') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"

mv composer.phar /usr/local/bin/composer

# Uncomment for magento version 2.2 or less

composer self-update ${COMPOSER_VERSION}

# Initilise database

echo "######### Initilise database"

echo "CREATE DATABASE ${MAGENTO_DATABASE};
CREATE USER '${MAGENTO_DATABASE_USERNAME}'@'localhost' IDENTIFIED BY '${MAGENTO_DATABASE_PASSWORD}';
ALTER USER '${MAGENTO_DATABASE_USERNAME}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MAGENTO_DATABASE_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO '${MAGENTO_DATABASE_USERNAME}'@'localhost' WITH GRANT OPTION;" | mysql -u root


### Apache configuration

echo "######### Update apache configurations"

# Add 8080 port to listen elasticsearch

echo "# If you just change the port or add more ports here, you will likely also
# have to change the VirtualHost statement in
# /etc/apache2/sites-enabled/000-default.conf

Listen 80
Listen 8080

<IfModule ssl_module>
        Listen 443
</IfModule>

<IfModule mod_gnutls.c>
        Listen 443
</IfModule>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet" | sudo tee /etc/apache2/ports.conf

echo "<VirtualHost *:80>
	# The ServerName directive sets the request scheme, hostname and port that
	# the server uses to identify itself. This is used when creating
	# redirection URLs. In the context of virtual hosts, the ServerName
	# specifies what hostname must appear in the request's Host: header to
	# match this virtual host. For the default virtual host (this file) this
	# value is not decisive as it is used as a last resort host regardless.
	# However, you must set it for any further virtual host explicitly.
	#ServerName www.example.com

	ServerAdmin webmaster@localhost
	DocumentRoot ${MAGENTO_DIR}

	# Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
	# error, crit, alert, emerg.
	# It is also possible to configure the loglevel for particular
	# modules, e.g.
	#LogLevel info ssl:warn

	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined

	# For most configuration files from conf-available/, which are
	# enabled or disabled at a global level, it is possible to
	# include a line for only one particular virtual host. For example the
	# following line enables the CGI configuration for this host only
	# after it has been globally disabled with \"a2disconf\".
	#Include conf-available/serve-cgi-bin.conf
</VirtualHost>

<Directory \"${MAGENTO_DIR}\">
    AllowOverride All
</Directory>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet" | sudo tee /etc/apache2/sites-available/${SITE_NAME}.conf


# Add ${SITE_NAME}-elasticsearch.conf

echo '<VirtualHost *:8080>
    ProxyPass "/" "http://localhost:9200/"
    ProxyPassReverse "/" "http://localhost:9200/"
</VirtualHost>' | tee /etc/apache2/sites-available/${SITE_NAME}-elasticsearch.conf


# Disable default site

echo "######### Disabling default apache site"
a2dissite 000-default

echo "######### Enabling new sites"

a2ensite ${SITE_NAME}
a2ensite ${SITE_NAME}-elasticsearch

a2enmod proxy_http rewrite

echo "######### Reload apache"

systemctl reload apache2

echo "######### Add magento user"
# Add magento user

useradd -s /bin/bash -m -p ${MAGENTO_SYSTEM_PASSWORD} ${MAGENTO_SYSTEM_USER}

# Add magento user to apache group

usermod -a -G www-data ${MAGENTO_SYSTEM_USER}


echo "######### Add composer crendentials to magento home dir"
# Add composer crendentials to magento home dir

# For composer 2 and above

# sudo -H -u ${MAGENTO_SYSTEM_USER} bash <<"EOF"
# cd
# mkdir -p ~/.config/composer
# echo '{
#     "http-basic": {
#         "repo.magento.com": {
#             "username": "418ecc0daef3f3081d36224fce2ed2cd",
#             "password": "d4b572998c3cad1beed8a4f0d3f9fa84"
#         }
#     }
# }' | tee ~/.config/composer/auth.json
# EOF

# For composer 1.4.1

sudo -H -u ${MAGENTO_SYSTEM_USER} bash <<"EOF"
cd
mkdir -p ~/.composer
echo '{
    "http-basic": {
        "repo.magento.com": {
            "username": "418ecc0daef3f3081d36224fce2ed2cd",
            "password": "d4b572998c3cad1beed8a4f0d3f9fa84"
        }
    }
}' | tee ~/.composer/auth.json
EOF


# echo "######### Installing magento"


# Clean 
rm -rf ${MAGENTO_DIR}

# Install magento
sudo MAGENTO_DIR=${MAGENTO_DIR} MAGENTO_VERSION=${MAGENTO_VERSION} -H -u ${MAGENTO_SYSTEM_USER} bash <<"EOF"
cd
composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition=${MAGENTO_VERSION} ${MAGENTO_DIR}
EOF

echo "######### Initilise magento"

sudo -H -u ${MAGENTO_SYSTEM_USER} bash -c "cd ${MAGENTO_DIR}; bin/magento setup:install \
--base-url=http://mywebsite.com \
--db-host=localhost \
--db-name=${MAGENTO_DATABASE} \
--db-user=${MAGENTO_DATABASE_USERNAME} \
--db-password=${MAGENTO_DATABASE_PASSWORD} \
--admin-firstname=Admin \
--admin-lastname=Admin \
--admin-email=${MAGENTO_ADMIN_EMAIL} \
--admin-user=${MAGENTO_ADMIN_USERNAME} \
--admin-password=${MAGENTO_ADMIN_PASSWORD} \
--language=en_US \
--currency=USD \
--timezone=America/Chicago \
--use-rewrites=1"

echo "######### Fix permission"
# Fix permission
sudo MAGENTO_DIR=${MAGENTO_DIR} -H -u ${MAGENTO_SYSTEM_USER} bash <<"EOF"
cd ${MAGENTO_DIR}
find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} +
find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} +
EOF

chown -R :www-data ${MAGENTO_DIR}

echo "######### Disable two factor"

# Disable two factor
sudo -H -u ${MAGENTO_SYSTEM_USER} bash -c "cd ${MAGENTO_DIR}; php bin/magento module:disable Magento_TwoFactorAuth"

echo "######### Restarting apache"
# Restart apache to apply all changes
systemctl restart apache2

echo "######### Magento installation finished"