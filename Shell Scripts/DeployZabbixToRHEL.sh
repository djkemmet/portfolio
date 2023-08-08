#
# Instructions for this script were taken from the install page for Zabbix 6.0LTS
# Source: hottps://www.zabbix.com/download?zabbix=6.0&os_distribution=red_hat_enterprise_linux&os_version=9&components=server_frontend_agent&db=mysql&ws=apache
#
#


#
# STEP 0: Solve this "SSL cert rejected mishigas" 
yum update


#
# STEP 0-a: RE-install a potentially missing or unacknowledged certificate
sudo yum -y reinstall $(rpm -qa | grep -i rhui-azure) --disablerepo=* --enablerepo="*microsoft*"
sudo echo $(. /etc/os-release && echo $VERSION_ID) > /etc/yum/vars/releasever

# STEP 1: Remove Zabbix Sources from EPEL
#         Not Necessary, EPEL not part of the azure Image.  


# Instal the Zabbix repository to our system. 
# View - yum repolist
rpm -Uvh https://repo.zabbix.com/zabbix/6.0/rhel/8/x86_64/zabbix-release-6.0-4.el8.noarch.rpm
dnf clean all

# STEP 3: Install zabbix packages and dependecies for a MySQL and Apache install. 
dnf install zabbix-server-mysql zabbix-web-mysql zabbix-apache-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent -y

# STEP 4: Install MySQL Server, configure it to run at startup. 
yum -y install @mysql
systemctl enable --now mysqld
systemctl start mysqld

# Set 5: Generate script to create and configure datbase
touch configureZabbixDB.sql
echo "create database zabbix character set utf8mb4 collate utf8mb4_bin;" >> configureZabbixDB.sql
echo "create user zabbix@localhost identified by 'password';" >> configureZabbixDB.sql
echo "grant all privileges on zabbix.* to zabbix@localhost;" >> configureZabbixDB.sql
echo "set global log_bin_trust_function_creators = 1;" >> configureZabbixDB.sql
echo "quit;" >> configureZabbixDB.sql

# Run the above script to create and configure database.
mysql < configureZabbixDB.sql

#Import the initial schema into our Zabbix Database
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u root

#WORKAROUND: around a "No Database Selected Error"

# Create the initial Schema
gunzip /usr/share/zabbix-sql-scripts/mysql/server.sql.gz 
cp /usr/share/zabbix-sql-scripts/mysql/server.sql /root/initialschema.sql # Copy initial schema script to home
sed -i '1s/^/USE zabbix; /' /root/initialschema.sql # update it to USE zabbix DB created above.
mysql --default-character-set=utf8mb4 < /root/initialschema.sql # With our updated schema file, populate the database.

# find and replace the password directive in the zabbix_server.conf file with a config that specs our password above
sed -i '/# DBPassword=/c\DBPassword=password' /etc/zabbix/zabbix_server.conf

# restart Services
systemctl restart zabbix-server zabbix-agent httpd php-fpm

#enable Services
systemctl enable zabbix-server zabbix-agent httpd php-fpm

# Configure the firewall to allow remote 80 and reload. 
firewall-cmd --zone=public --permanent --add-service=http
firewall-cmd --reload