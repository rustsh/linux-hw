#!/bin/bash

### Создание RPM-пакета

echo '=================================='
echo ' Provisioning for RPM has started'
echo '=================================='

# Переходим в домашний каталог пользователя root
cd /root

# Установим все нужные пакеты
yum install -y redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils gcc

# Загрузим SRPM пакет Nginx для дальнейшей работы над ним
wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.14.1-1.el7_4.ngx.src.rpm

# Установим загруженный пакет Nginx в домашнем каталоге пользователя root
rpm -i nginx-1.14.1-1.el7_4.ngx.src.rpm

# Скачаем и разархивируем исходники для openssl
wget https://www.openssl.org/source/latest.tar.gz
tar -xf latest.tar.gz

# Поставим все зависимости, чтобы в процессе сборки не было ошибок
yum-builddep -y rpmbuild/SPECS/nginx.spec

# Добавим параметр --with-openssl с путём до распакованных исходников в spec-файл, чтобы Nginx собирался с необходимыми опциями
ospath="\    --with-openssl=/root/$(ls | grep openssl) \\\\"
sed -i "/\.\/configure/a $ospath" rpmbuild/SPECS/nginx.spec

# Соберём RPM-пакет
rpmbuild -bb rpmbuild/SPECS/nginx.spec

# Установим наш пакет и запустим службу nginx
yum localinstall -y rpmbuild/RPMS/x86_64/nginx-1.14.1-1.el7_4.ngx.x86_64.rpm
systemctl start nginx
systemctl enable nginx

echo '==================================='
echo ' Provisioning for RPM has finished'
echo '==================================='