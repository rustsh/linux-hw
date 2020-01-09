#!/bin/bash

echo '============================================'
echo ' Provisioning for the star task has started'
echo '============================================'

# Install wget
yum install -y wget

# Install Java
yum install -y java-1.8.0-openjdk

# Set Java’s Home Environment
echo export JAVA_HOME=$(readlink -nf $(which java) | xargs dirname | xargs dirname) >> /etc/environment

# Create the install directory where Jira will be installed and the home directory which holds the application data
mkdir -p /opt/atlassian/jira
mkdir -p /var/atlassian/application-data/jira

# Download Jira tar.gz archive and extract it into install directory
wget https://product-downloads.atlassian.com/software/jira/downloads/atlassian-jira-software-8.6.0.tar.gz
tar zxvf atlassian-jira-software-8.6.0.tar.gz -C /opt/atlassian/jira --strip-components 1

# Create user for Jira
useradd --create-home -c "Jira role account" jira

# Change ownership of the install and home directories
chown -R jira: /opt/atlassian/jira
chown -R jira: /var/atlassian/application-data/jira

# Define in Jira where the home directory is located
sed -i 's|^jira.home =|jira.home = /var/atlassian/application-data/jira|' /opt/atlassian/jira/atlassian-jira/WEB-INF/classes/jira-application.properties

# Copy Jira Unit file to /etc/systemd/system/
cp /vagrant/files/star-task/jira.service /etc/systemd/system/

# Start and enable Jira service
systemctl start jira
systemctl enable jira

echo '============================================='
echo ' Provisioning for the star task has finished'
echo '============================================='