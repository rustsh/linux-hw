#!/bin/bash

echo '=============================================='
echo ' Provisioning for the second task has started'
echo '=============================================='

# Install required packages 
yum install -y epel-release
yum install -y spawn-fcgi php php-cli mod_fcgid httpd

# Replace spawn-fcgi options file
cat /vagrant/files/second-task/spawn-fcgi > /etc/sysconfig/spawn-fcgi

# Copy Unit file to /etc/systemd/system/
cp /vagrant/files/second-task/spawn-fcgi.service /etc/systemd/system/

# Run and enable spawn-fcgi service
systemctl start spawn-fcgi
systemctl enable spawn-fcgi

echo '==============================================='
echo ' Provisioning for the second task has finished'
echo '==============================================='