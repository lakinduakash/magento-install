#!/bin/bash

### Config

# magento

MAGENTO_ADMIN_USERNAME=admin
MAGENTO_ADMIN_EMAIL=admin@admin.com
MAGENTO_ADMIN_PASSWORD=admin@123

# Database
MAGENTO_DATABASE=magento 
MAGENTO_DATABASE_USERNAME=magentip
MAGENTO_DATABASE_PASSWORD=magento@123

SITE_NAME=mydomain # Site domain
BASE_URL=http://mydomain.com

# For ftp
MAGENTO_SYSTEM_USER=magento
MAGENTO_SYSTEM_PASSWORD=magento@123

#Elasticsearch
ELASTICSEARCH_HOST=localhost
ELASTICSEARCH_PORT=8080


## VERSIONS

MAGENTO_VERSION=2.4.4
MYSQL_VERSION=8.0.*
PHP_VERSION=8.1
ELASTICSEARCH_VERSION=7.13.*
APACHE_VERSION=2.*
COMPOSER_VERSION=2.2

# JAVA_VERSION=8


# Read options

OPTS=`getopt -o "" --long magento-username:,magento-email:,magento-password:,database:,database-user:,database-password:,site-name:,base-url:,system-user:,system-password:,elasticsearch-host:,elasticsearch-port: -- "$@"`
eval set -- "$OPTS"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
		--magento-username)
            MAGENTO_ADMIN_USERNAME=$2 ; shift 2 ;;
        	--magento-email)
            MAGENTO_ADMIN_EMAIL=$2 ; shift 2 ;;
        	--magento-password)
            MAGENTO_ADMIN_PASSWORD=$2 ; shift 2;;
		--database)
            MAGENTO_DATABASE=$2 ; shift 2;;
		--database-user)
            MAGENTO_DATABASE_USERNAME=$2 ; shift 2;;
		--database-password)
            MAGENTO_DATABASE_PASSWORD=$2 ; shift 2;;
		--site-name)
            SITE_NAME=$2 ; shift 2;;
		--base-url)
            BASE_URL=$2 ; shift 2;;
		--system-user)
            MAGENTO_SYSTEM_USER=$2 ; shift 2;;	
		--system-password)
            MAGENTO_SYSTEM_PASSWORD=$2 ; shift 2;;
	    	--elasticsearch-host)
	    ELASTICSEARCH_HOST=$2 ; shift 2;;
	    	--elasticsearch-port)
	    ELASTICSEARCH_PORT=$2 ; shift 2;;

        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi


# Magento installation directory

# MAGENTO_DIR=/var/www/html/${SITE_NAME}
MAGENTO_DIR=/home/${MAGENTO_SYSTEM_USER}/${SITE_NAME}

echo "Magento installation directory: ${MAGENTO_DIR}"

### Start installation

apt-get update -q

sudo add-apt-repository -y ppa:ondrej/php

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
	unzip \
	openssl

# Install php extensions

apt-get install -yq php${PHP_VERSION}-{mysql,mcrypt,gd,curl,intl,bcmath,ctype,dom,iconv,mbstring,simplexml,soap,xsl,zip}

# Install elasticsearch

# wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -

# echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-7.x.list

# apt-get update && apt-get install -yq elasticsearch=${ELASTICSEARCH_VERSION}


# Start elasticsearch

# echo "Enabling and starting Elasticsearch..."

# systemctl enable elasticsearch
# systemctl start elasticsearch

# echo "Enabling and starting Elasticsearch...OK"

# Install composer


echo "Intalling composer..."

php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === '55ce33d7678c5a611085589f1f3ddf8b3c52d662cd01d4ba75c0ee0459970c2200a51f492d557530c71c15d8dba01eae') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php --${COMPOSER_VERSION}
php -r "unlink('composer-setup.php');"

mv composer.phar /usr/local/bin/composer

echo "Intalling coposer...OK"

# Initilise database

echo -n "Initilise database..."

echo "CREATE DATABASE ${MAGENTO_DATABASE};
CREATE USER '${MAGENTO_DATABASE_USERNAME}'@'localhost' IDENTIFIED BY '${MAGENTO_DATABASE_PASSWORD}';
ALTER USER '${MAGENTO_DATABASE_USERNAME}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${MAGENTO_DATABASE_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO '${MAGENTO_DATABASE_USERNAME}'@'localhost' WITH GRANT OPTION;" | mysql -u root

echo "OK"

### Apache configuration

echo -n "Updating apache configurations..."

# Add 8080 port to listen elasticsearch

echo "# If you just change the port or add more ports here, you will likely also
# have to change the VirtualHost statement in
# /etc/apache2/sites-enabled/000-default.conf

Listen 80
# Listen 8080

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
	ServerName ${SITE_NAME}

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

# Update /etc/apache2.conf

sed "s+MAGENTO_HOME_DIR+/home/${MAGENTO_SYSTEM_USER}+g" apache2.conf > /etc/apache2/apache2.conf

# Add ${SITE_NAME}-elasticsearch.conf

# echo '<VirtualHost *:8080>
#    ProxyPass "/" "http://localhost:9200/"
#    ProxyPassReverse "/" "http://localhost:9200/"
# </VirtualHost>' | tee /etc/apache2/sites-available/${SITE_NAME}-elasticsearch.conf


# echo "OK"

# Disable default site

echo "Disabling default apache site..."
a2dissite 000-default

echo "Enabling new site..."

a2ensite ${SITE_NAME}

# a2ensite ${SITE_NAME}-elasticsearch

a2enmod proxy_http rewrite

echo "Reload apache"

systemctl reload apache2

echo -n "Adding magento user..."
# Add magento user

sudo useradd -m -p $(openssl passwd -1 ${MAGENTO_SYSTEM_PASSWORD}) -s /bin/bash ${MAGENTO_SYSTEM_USER}

# Add magento user to apache group

usermod -a -G www-data ${MAGENTO_SYSTEM_USER}

echo "OK"

echo -n "Adding composer crendentials to magento home dir..."
# Add composer crendentials to magento home dir

# For composer 2 and above

sudo -H -u ${MAGENTO_SYSTEM_USER} bash <<"EOF"
cd
mkdir -p ~/.config/composer
echo '{
    "http-basic": {
        "repo.magento.com": {
            "username": "418ecc0daef3f3081d36224fce2ed2cd",
            "password": "d4b572998c3cad1beed8a4f0d3f9fa84"
        }
    }
}' | tee ~/.config/composer/auth.json
EOF

echo "OK"

echo "Starting Install magento"

# Clean 
rm -rf ${MAGENTO_DIR}

# Install magento
sudo MAGENTO_DIR=${MAGENTO_DIR} MAGENTO_VERSION=${MAGENTO_VERSION} -H -u ${MAGENTO_SYSTEM_USER} bash <<"EOF"
cd
composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition=${MAGENTO_VERSION} ${MAGENTO_DIR}
EOF

echo "Initilise magento"

sudo -H -u ${MAGENTO_SYSTEM_USER} bash -c "cd ${MAGENTO_DIR}; bin/magento setup:install \
--base-url=${BASE_URL} \
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
--timezone=Australia/Sydney \
--elasticsearch-host=${ELASTICSEARCH_HOST} \
--elasticsearch-port=${ELASTICSEARCH_PORT} \
--use-rewrites=1"

echo "Initilise magento...OK"

echo "Fix permission..."
# Fix permission
sudo MAGENTO_DIR=${MAGENTO_DIR} -H -u ${MAGENTO_SYSTEM_USER} bash <<"EOF"
cd ${MAGENTO_DIR}
find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} +
find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} +
EOF

chown -R ${MAGENTO_SYSTEM_USER}:www-data ${MAGENTO_DIR}

echo "Fix permission...OK"

echo "######### Disable two factor"

# Disable two factor
sudo -H -u ${MAGENTO_SYSTEM_USER} bash -c "cd ${MAGENTO_DIR}; php bin/magento module:disable Magento_TwoFactorAuth; bin/magento cron:install"

echo "Restarting apache..."
# Restart apache to apply all changes
systemctl restart apache2

echo "Restarting apache...OK"
echo "######### Magento installation finished ########"

# Install ftp file server

# apt install vsftpd

# sed -i "s+#write_enable=YES+write_enable=YES+g" /etc/vsftpd.conf

# systemctl restart vsftpd

# Ftp server is ready
