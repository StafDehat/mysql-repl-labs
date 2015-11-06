#!/bin/bash

# Intended setup:
# FTWRL & rsync directly from datadir
# Not enough room for mysqldump, not LVM so can't snapshot

# Confirm CBS is attached as /dev/xvde
if [ ! -b /dev/xvde ]; then
  echo "ERROR: No CBS volume detected at /dev/xvde"
  echo "Attach a CBS volume and retry"
  exit 1
fi


# Setup LVM
yum -y install parted
parted -s -- /dev/xvde mklabel msdos
parted -s -a optimal -- /dev/xvde mkpart extended 2048s 15G
PART=$( parted /dev/xvde unit s print | grep extended )
END=$( echo "$PART" | awk '{print $3}' )
parted -s -a optimal -- /dev/xvde mkpart logical 4096s $END
parted -s -- /dev/xvde align-check optimal 5
mkfs -t ext4 /dev/xvde5
mkdir /data
mount /dev/xvde5 /data
grep /dev/xvde5 /etc/mtab >> /etc/fstab


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


# Initialize entropy
touch /var/log/entropy.log
echo 1 > /home/lab/entropy
/home/lab/entropy.sh


# Replace the 'df' binary, so disks look full
df=$( which df )
cp -p $df{,.bak}
cat /home/lab/df > $df



