#!/bin/bash

echo '============================================='
echo ' Provisioning for the third task has started'
echo '============================================='

# Install httpd
yum install -y httpd

# Copy required files
cp /vagrant/files/third-task/httpd@.service /etc/systemd/system/
cp /vagrant/files/third-task/httpd-first /etc/sysconfig/
cp /vagrant/files/third-task/httpd-second /etc/sysconfig/
cp /vagrant/files/third-task/first.conf /etc/httpd/conf/
cp /vagrant/files/third-task/second.conf /etc/httpd/conf/

# Run httpd with different options
systemctl start httpd@first
systemctl start httpd@second

echo '=============================================='
echo ' Provisioning for the third task has finished'
echo '=============================================='