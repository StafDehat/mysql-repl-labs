#!/bin/bash

# Scenario
# Binlog-format is STATEMENT, but our entropy script is running 
# unsafe queries constantly - RAND().  That'll break eventually, but not
# reliably, so to drive the point home I used LOAD_FILE() too.
# Run this on master

# Confirm CBS is attached as /dev/xvde
if [ ! -b /dev/xvde ]; then
  echo "ERROR: No CBS volume detected at /dev/xvde"
  echo "Attach a CBS volume and retry"
  exit 1
fi


# Setup LVM
yum -y install parted lvm2
parted -s -- /dev/xvde mklabel gpt
parted -s -a optimal -- /dev/xvde mkpart primary 0% 100%
parted -s -- /dev/xvde align-check optimal 1
parted -s -- /dev/xvde set 1 lvm on
pvcreate /dev/xvde1
vgcreate vg00 /dev/xvde1
lvcreate -L15G -n lv00 vg00
mkfs -t ext4 /dev/mapper/vg00-lv00
mkdir /data
mount /dev/mapper/vg00-lv00 /data
grep /dev/mapper/vg00-lv00 /etc/mtab >> /etc/fstab


# Setup MySQL
yum -y install mysql-server
mkdir /data/mysqllogs
mkdir /data/mysqltmp
tar -C /data -xzf /home/lab/master-data.tgz
tar -C /data -xzf /home/lab/master-logs.tgz
# Master position = binlog.000004, 6260
chown mysql:mysql /data/mysqltmp
chown mysql:mysql /data/mysqllogs
chown -R mysql:mysql /data/mysql
echo > /var/log/mysqld.log
cat >/etc/my.cnf <<EOF
[mysqld]
datadir=/data/mysql
socket=/var/lib/mysql/mysql.sock
user=mysql
# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0
tmpdir = /data/mysqltmp
log-bin = /data/mysqllogs/binlog
binlog-format = STATEMENT
server-id = 1

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
EOF


# Start the service
service mysqld start


# Add replication grants for private ranges
mysql -e "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'10.%' IDENTIFIED BY 'dkMcn5Vtgv';"
mysql -e "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'192.168.%' IDENTIFIED BY 'dkMcn5Vtgv';"
# I know.  I don't care.
mysql -e "GRANT REPLICATION SLAVE ON *.* TO 'repl'@'172.%' IDENTIFIED BY 'dkMcn5Vtgv';"


# Initialize entropy
echo 1 > /home/lab/entropy
/home/lab/entropy.sh


# Break things
date +"%F %T" > /var/log/test
mysql ecom -e "INSERT INTO orders (count, time) values ('$RANDOM', LOAD_FILE('/var/log/test') );"


