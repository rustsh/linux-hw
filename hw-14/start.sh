#!/usr/bin/env bash

# Добавляем новых пользователей и назначаем им пароли
useradd first
useradd second
echo "Qwerty123" | passwd --stdin first
echo "Qwerty123" | passwd --stdin second

# Создаём группу admin и добавляем туда одного из пользователей
groupadd admin
gpasswd -a first admin
gpasswd -a vagrant admin

# Разрешим вход через SSH по паролю
sed -i 's/^PasswordAuthentication.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd.service

# Копируем проверочный скрипт в /usr/local/bin/ и делаем его исполняемым
cp /vagrant/check_login.sh /usr/local/bin
chmod +x /usr/local/bin/check_login.sh

# Добавляем использование скрипта в файл сценария PAM для sshd
sed -i '/pam_nologin.so/a\account    required     pam_exec.so /usr/local/bin/check_login.sh' /etc/pam.d/sshd