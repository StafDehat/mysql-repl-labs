#!/bin/bash

# Scenario
# The slave is updated manually.  Evidence of this is in the slave binlogs.
# Replication breaks when a query affecting that row comes in from master,
# and errors because it encounters unexpected data at slave.


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
relay-log = /data/mysqllogs/relaylog
server-id = 2

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
EOF


# Start the service
service mysqld start


# Start slave
read -p "Private IP of db1/master? " MASTERIP
mysql -e "CHANGE MASTER TO MASTER_HOST='$MASTERIP',
                           MASTER_USER='repl',
                           MASTER_PASSWORD='dkMcn5Vtgv',
                           MASTER_LOG_FILE='binlog.000004',
                           MASTER_LOG_POS=6260;"
mysql -e "START SLAVE;"


# Break replication
sleep 15
mysql ecom -e "DELETE FROM orders ORDER BY RAND() LIMIT 1;"
sleep 15



