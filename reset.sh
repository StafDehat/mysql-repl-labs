#!/bin/bash

if [ $( pwd | grep -cE '^/data' ) -gt 0 ]; then
  echo "Get out of /data first, yo"
  exit
fi

yum -y install lsof lvm2

# Disable entropy
echo 2 > /home/lab/entropy
sleep 5
logrotate -f /etc/logrotate.d/entropy
touch > /var/log/entropy.log

# Stop MySQL
service mysqld stop
killall mysqld mysqld-safe
killall -9 mysqld mysqld-safe

# Kill anything touching /data
lsof /data

# Unmount
umount /data

# Delete mount point
rmdir /data

# Clean up fstab
sed -i '/\/data/d' /etc/fstab

# Teardown LVM
lvs | tail -n +2 | while read LINE; do
  yes | lvremove $( echo "$LINE" | awk '{print $2"/"$1}' )
done
for x in $( vgs | tail -n +2 | awk '{print $1}' ); do
  vgremove $x
done
for x in $( pvs | tail -n +2 | awk '{print $1}' ); do
  pvremove $x
done

# Replace df binary
df=$( which df )
if [ -e $df.bak ]; then
  rm -f $df
  mv $df.bak $df
fi

# Blow away old logs
echo > /var/log/mysqld.log

# Delete the test file
rm -f /var/log/test


