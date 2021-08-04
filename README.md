# Magento 2.4 Single Click Installation

This script will initilse new magento server with apache for ubuntu 18.04+. This script is intend to run on very new OS installation. If you use this in exsiting web server make sure to backup Apache configurations, MySql database etc.

This will install `ftp` server for magento home directory also.

## How to Install

Clone the git repository and go into cloned folder

```
git clone https://github.com/lakinduakash/magento-install
cd magento-install

```


Then run the magento_install.sh script as root user with the following arguments. Change the argument values as necessary.

### Arguments

Every argument is optional and default value will be applied if ommited.

| Argument            | Description                                      | Default             |
|---------------------|--------------------------------------------------|---------------------|
| --magento-user      | Magento admin user                               | admin               |
| --magento-email     | Email for magento admin                          | admin@admin.com     |
| --magento-password  | Magento admin password                           | admin@123           |
| --database          | Magento database name                            | magentoip           |
| --database-user     | Magento database user                            | magentoip           |
| --database-password | Magento database password                        | magento@123         |
| --site-name         | Domain name or magento site name                 | mydomain.com        |
| --base-url          | Magento base URL                                 | http://mydomain.com |
| --system-user       | New system user for Magento <br>file permissions | magento             |
| --system-password   | Magento system user password                     | magento@123         |


system-user and system-password can be used to log into ftp server

### Example

 ```bash
  sudo ./magento_install.sh --magento-username admin \
    --magento-email admin@admin.com \
    --magento-password admin@123 \
    --database magento \
    --database-user magentoip \
    --database-password magento@123 \
    --site-name mydomain.com \
    --base-url http://mydomain.com \
    --system-user=magento \
    --system-password=magento@123
```

It will take a few minutes to complete.

After installation, the admin url is printed as follows, Note the Magento Admin URI.

```
....
[SUCCESS]: Magento installation complete.
[SUCCESS]: Magento Admin URI: /admin_5da86s
Nothing to import.
```


### This will install/update following software
 
- Magento 2.4.2
- MySql 8.0.x
- PHP 7.4
- Elasticsearch 7.13.x
- Apache2
- Composer 2.x
 
