#!/bin/bash

# Intended method:
# FTWRL & LVM snapshot & rsync
# Unused space in VG allows for LVM snapshot

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

