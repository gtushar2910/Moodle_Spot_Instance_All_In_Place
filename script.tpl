#!/bin/bash
sleep 1m
sudo su - root
apt-get update
apt-get install -y nginx
systemctl start nginx
systemctl enable nginx
apt-get update
apt-get install -y php7.4-fpm php7.4-common php7.4-mysql php7.4-gmp php7.4-curl php7.4-intl php7.4-mbstring php7.4-soap php7.4-xmlrpc php7.4-gd php7.4-xml php7.4-cli php7.4-zip
cd /var/www/
git clone -b MOODLE_39_STABLE git://git.moodle.org/moodle.git moodle
wget https://terraform-triple5.s3.amazonaws.com/moodle -P /etc/nginx/sites-available/
sed -i "s/server_name  moodle.triple5.in;/server_name  ${url};/g" /etc/nginx/sites-available/moodle
ln -s /etc/nginx/sites-available/moodle /etc/nginx/sites-enabled/
systemctl restart nginx.service

chown -R www-data:www-data /var/www/
chmod -R 755 /var/www/

mkdir /var/moodledata
chown -R www-data:www-data /var/moodledata/
chmod -R 755 /var/moodledata/
echo "request_terminate_timeout = 360" >> /etc/php/7.4/fpm/pool.d/www.conf

apt-get install -y mariadb-server mariadb-client
systemctl enable mariadb.service

MYSQL=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $11}')
MYSQL_ROOT_PASSWORD=${root_password}

SECURE_MYSQL=$(expect -c "

      set timeout 10
      spawn mysql_secure_installation

      expect "Enter password for user root:"
      send "$MYSQL\r"

      expect "Change the password for root ?\(Press y\|Y for Yes, any other key for No\) :"
      send "y\r"

      expect "New password:"
      send "$MYSQL_ROOT_PASSWORD\r"

      expect "Re-enter new password:"
      send "$MYSQL_ROOT_PASSWORD\r"

      expect "Do you wish to continue with the password provided?\(Press y\|Y for Yes, any other key for No\) :"
      send "y\r"

      expect "Remove anonymous users?\(Press y\|Y for Yes, any other key for No\) :"
      send "y\r"

      expect "Disallow root login remotely?\(Press y\|Y for Yes, any other key for No\) :"
      send "y\r"

      expect "Remove test database and access to it?\(Press y\|Y for Yes, any other key for No\) :"
      send "y\r"

      expect "Reload privilege tables now?\(Press y\|Y for Yes, any other key for No\) :"
      send "y\r"

      expect eof
      ")

echo "$SECURE_MYSQL"

MYSQL=`which mysql`
 
$MYSQL -uroot -p${root_password} -e "CREATE DATABASE IF NOT EXISTS ${moodledb};"
$MYSQL -uroot -p${root_password} -e "GRANT ALL ON *.* TO '${moodleuser}'@'localhost' IDENTIFIED BY '${moodlepwd}';"
$MYSQL -uroot -p${root_password} -e "FLUSH PRIVILEGES;"

sed '/#skip-external-locking/a innodb_file_format = Barracuda \n innodb_file_per_table = 1 \n innodb_large_prefix = ON' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i 's/max_execution_time = 30/max_execution_time = 360/g' /etc/php/7.4/fpm/php.ini
wget https://terraform-triple5.s3.amazonaws.com/config.php -P /var/www/moodle/

sed -i 's/max_execution_time = 30/max_execution_time = 360/g' /etc/php/7.4/fpm/php.ini
sed -i "s/\$CFG->dbname    = 'moodle';/\$CFG->dbname    = '${moodledb}';/g" /var/www/moodle/config.php
sed -i "s/\$CFG->dbuser    = 'moodleuser';/\$CFG->dbuser    = '${moodleuser}';/g" /var/www/moodle/config.php
sed -i "s/\$CFG->dbpass    = 'Admin@2020';/\$CFG->dbpass    = '${moodlepwd}';/g" /var/www/moodle/config.php
sed -i "s/\$CFG->wwwroot   = 'https:\/\/www.scetitmoodle.tech';/\$CFG->wwwroot   = 'https:\/\/${url}';/g" /var/www/moodle/config.php

snap install --classic certbot
certbot --nginx --agree-tos --no-eff-email --email ${email} -d ${url}

echo "* * * * * /usr/bin/php  /var/www/moodle/admin/cli/cron.php >/dev/null" > mycron 
crontab -u www-data mycron
