#!/bin/bash

### Создание репозитория

echo '==================================='
echo ' Provisioning for repo has started'
echo '==================================='

# Создадим каталог repo в директории /usr/share/nginx/html
mkdir /usr/share/nginx/html/repo

# Копируем туда собранный RPM и RPM для установки репозитория Percona-Server
cp /root/rpmbuild/RPMS/x86_64/nginx-1.14.1-1.el7_4.ngx.x86_64.rpm /usr/share/nginx/html/repo/
wget http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm -O /usr/share/nginx/html/repo/percona-release-0.1-6.noarch.rpm

# Инициализируем репозиторий
createrepo /usr/share/nginx/html/repo/

# Настроим в Nginx доступ к листингу каталога
# Для этого в location / в файле /etc/nginx/conf.d/default.conf добавим директиву autoindex on
sed -i '/index.html index.htm/a \        autoindex on;' /etc/nginx/conf.d/default.conf

# Перезапускаем Nginx
nginx -s reload

# Добавим репозиторий в /etc/yum.repos.d
cat >> /etc/yum.repos.d/otus.repo << EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF

echo '===================================='
echo ' Provisioning for repo has finished'
echo '===================================='