## Домашнее задание к занятию № 31 — «Почта: SMTP, IMAP, POP3»  <!-- omit in toc -->

### Оглавление  <!-- omit in toc -->

- [Задание](#задание)
- [Описание работы](#описание-работы)
- [Проверка работы](#проверка-работы)
  - [Отправка почты](#отправка-почты)
  - [Получение почты](#получение-почты)

### Задание

1. Установить в виртуалке postfix+dovecot для приёма почты на виртуальный домен.
2. Отправить почту телнетом с хоста на виртуалку.
3. Принять почту на хост почтовым клиентом.

### Описание работы

В работе настраивается простейшая связка postfix + dovecot без дополнительных сервисов и баз данных, но с использованием виртуального домена. Все пользователи виртуальных почтовых ящиков ассоциируются со специально созданным в системе пользователем vmail, их пароли хранятся в файле.

При выполнении команды `vagrant up` поднимается виртуальная машина mail ([Vagrantfile](Vagrantfile)), которая конфигурируется при помощи Ansible.

Шаги предварительной настройки:

1. Создаётся группа для пользователя, а затем и сам пользователь vmail для владения каталогом с виртуальными доменами и почтовыми ящиками (uid = 5000, gid = 5000).
2. Создаётся каталог **/var/spool/mail/vhosts** для виртуальных доменов, внутри него — каталог домена **virtual.otus**, их владельцем назначается пользователь vmail.
3. Проверяется, установлен ли в системе postfix, если нет — устанавливается.
4. Производится настройка postfix:

   - В файл [/etc/postfix/main.cf](provisioning/roles/mail/templates/postfix/main.cf.j2) вносятся основные настройки (в дополнение к настройкам по умолчанию):
        
        ```
        myhostname = mail.otus.lan
        mydomain = otus.lan
        myorigin = $mydomain
        inet_interfaces = all
        inet_protocols = all
        mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
        mynetworks = 192.168.0.0/16, 127.0.0.0/8
        home_mailbox = Maildir/
        smtpd_banner = $myhostname ESMTP $mail_name
        ```

   - В файл [/etc/postfix/main.cf](provisioning/roles/mail/templates/postfix/main.cf.j2) вносятся настройки для виртуальных доменов и почтовых ящиков:

       - `virtual_mailbox_domains = virtual.otus` — перечисление виртуальных доменов, для которых будет приниматься почта;
       - `virtual_mailbox_base = /var/spool/mail/vhosts` — базовый путь (префикс), где будут лежать почтовые ящики;
       - `virtual_mailbox_maps = hash:/etc/postfix/vmailbox` — путь до файла, где будут прописаны названия виртуальных почтовых ящиков и соответствующие им относительные пути до почтовых хранилищ;
       - `virtual_minimum_uid = 100` — минимальный uid, который может иметь владелец почтовых хранилищ (введен для повышения безопасности);
       - `virtual_uid_maps = static:5000` — uid владельца всех виртуальных почтовых хранилищ;
       - `virtual_gid_maps = static:5000` — gid владельца всех виртуальных почтовых хранилищ;
       - дополнительно может быть указан параметр `virtual_alias_maps = hash:/etc/postfix/virtual` — путь до файла, в котором могут храниться синонимы для перенаправления почты между доменами. В данной работе не используется.

   - В каталог **/etc/postfix** копируется файл [vmailbox](provisioning/roles/mail/templates/vmailbox.j2) c названиями почтовых ящиков и относительными путями до почтовых хранилищ:

        ```
        student@virtual.otus virtual.otus/student/Maildir/
        teacher@virtual.otus virtual.otus/teacher/Maildir/
        manager@virtual.otus virtual.otus/manager/Maildir/
        ```

        Абсолютный путь до почтового хранилища собирается из базового пути (заданного в параметре `virtual_mailbox_base`) и относительного пути. Таким орбазом, полный путь до почтового хранилища ящика student@vitual.otus следующий: **/var/spool/mail/vhosts/virtual.otus/student/Maildir**.

   - Выполняется команда:

        ```
        postmap /etc/postfix/vmailbox
        ```

        В результате в каталоге **/etc/postfix** создаётся файл **vmailbox.db**, который и будет использоваться postfix'ом.

5. Postfix перезапускается.
6. Устанавливается dovecot.
7. В файлы конфигурирования dovecot вносятся изменения:

   - [/etc/dovecot/dovecot.conf](provisioning/roles/mail/files/dovecot/dovecot.conf) — раскомментируются строки:

        ```
        protocols = imap pop3 lmtp
        listen = *
        ```

   - [/etc/dovecot/conf.d/10-auth.conf](provisioning/roles/mail/templates/dovecot/10-auth.conf.j2):

        ```
        disable_plaintext_auth = no
        auth_default_realm = virtual.otus
        auth_mechanisms = plain login
        !include auth-passwdfile.conf.ext
        !include auth-static.conf.ext
        ```

   - [/etc/dovecot/conf.d/10-logging.conf](provisioning/roles/mail/files/dovecot/conf.d/10-logging.conf):

        ```
        log_path = /var/log/dovecot.log
        info_log_path = /var/log/dovecot-info.log
        ```

   - [/etc/dovecot/conf.d/10-mail.conf](provisioning/roles/mail/files/dovecot/conf.d/10-mail.conf):

        ```
        mail_location = maildir:/var/spool/mail/vhosts/%d/%n/Maildir
        ```

   - [/etc/dovecot/conf.d/10-ssl.conf](provisioning/roles/mail/files/dovecot/conf.d/10-ssl.conf):

        ```
        ssl = no
        ```

   - [/etc/dovecot/conf.d/auth-passwdfile.conf.ext](provisioning/roles/mail/files/dovecot/conf.d/auth-passwdfile.conf.ext):

        ```
        passdb {
          driver = passwd-file
          args = scheme=plain username_format=%n /etc/dovecot/users
        }
        ```

   - [/etc/dovecot/conf.d/auth-static.conf.ext](provisioning/roles/mail/files/dovecot/conf.d/auth-static.conf.ext):

        ```
        userdb {
          driver = static
          args = uid=vmail gid=vmail home=/home/%d/%n
        }
        ```

8. В каталог **/etc/dovecot** копируется файл [users](provisioning/roles/mail/files/dovecot/users), в котором хранятся пароли пользователей виртуальных почтовых ящиков.
9. Dovecot перезапускается.
10. Пользователь vmail назначается владельцем лог-файлов (**/var/log/dovecot.log** и **/var/log/dovecot-info.log**), иначе отправленные письма не будут приходить на почтовые ящики на удалённых машинах: postfix при отправке должен иметь возможность записи в этот лог-файлы, при этом postfix осуществляет авторизацию средствами dovecot от имени непривилегированной учетной записи vmail.

### Проверка работы



#### Отправка почты



#### Получение почты



<br/>

[Вернуться к списку всех ДЗ](../README.md)
