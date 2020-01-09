#!/bin/bash

echo '============================================='
echo ' Provisioning for the first task has started'
echo '============================================='

# Copy required files
cp /vagrant/files/first-task/watchlog /etc/sysconfig/
cp /vagrant/files/first-task/watchlog.sh /opt/
cp /vagrant/files/first-task/watchlog.service /etc/systemd/system/
cp /vagrant/files/first-task/watchlog.timer /etc/systemd/system/

# Create log file to monitor
touch /var/log/watchlog.log

# Make shell script executable (otherwise we will get 'Permission denied' message)
chmod +x /opt/watchlog.sh

# Run and enable timer
systemctl start watchlog.timer
systemctl enable watchlog.timer

echo '=============================================='
echo ' Provisioning for the first task has finished'
echo '=============================================='