#!/bin/bash

# Intended setup:
# mysqldump --all-databases --master-data=2 --single-transaction
# No free space in VG, so can't snapshot, but all tables are InnoDB
# so we can use --single-transaction to avoid locking.

# Confirm CBS is attached as /dev/xvde
if [ ! -b /dev/xvde ]; then
  echo "ERROR: No CBS volume detected at /dev/xvde"
  echo "Attach a CBS volume and retry"
  exit 1
fi


# Setup LVM
yum -y install parted
parted -s -- /dev/xvde mklabel gpt
parted -s -a optimal -- /dev/xvde mkpart primary 0% 100%
parted -s -- /dev/xvde align-check optimal 1
mkfs -t ext4 /dev/xvde1
mkdir /data
mount /dev/xvde1 /data
grep /dev/xvde1 /etc/mtab >> /etc/fstab


# Setup MySQL
yum -y install mysql-server
mkdir /data/mysqllogs
mkdir /data/mysqltmp
tar -C /data -xzf /home/lab/datadir.tgz
chown mysql:mysql /data/mysqllogs
chown mysql:mysql /data/mysqltmp
chown -R mysql:mysql /data/mysql
echo > /var/log/mysqld.log
cat >/etc/my.cnf <<EOF
[mysqld]
datadir=/data/mysql
socket=/var/lib/mysql/mysql.sock
user=mysql
# Disabling symbolic-links is recommended to prevent assorted security risks
tmpdir = /data/mysqltmp
symbolic-links=0

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
EOF


# Start the service
service mysqld start


# Convert everything to InnoDB
echo "This next step will take awhile.  Be patient."
DBS=$( mysql --skip-column-names -e "show databases;" | 
         grep -vE '^(mysql|information_schema)$' )
for DB in $DBS; do
  TBLS=$( mysql $DB --skip-column-names -e "show tables;" )
  for TBL in $TBLS; do
    mysql $DB -e "ALTER TABLE $TBL ENGINE=InnoDB;"
  done
done


# Initialize entropy
touch /var/log/entropy.log
echo 1 > /home/lab/entropy
/home/lab/entropy.sh

