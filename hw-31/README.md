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

1. Создаётся группа для пользователя, а затем и сам пользователь vmail для владения каталогом с виртуальными доменами и почтовыми ящиками (uid = 5000, gid = 5000).
2. Создаётся каталог **/var/spool/mail/vhosts** для виртуальных доменов, внутри него — каталог домена **virtual.otus**, их владельцем назначается пользователь vmail.
3. Проверяется, установлен ли в системе postfix, если нет — устанавливается.
4. Производится настройка postfix:

   - В файл **/etc/postfix/main.cf** вносятся основные настройки (в дополенение к настройкам по умолчанию):
        
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

   - В файл **/etc/postfix/main.cf** вносятся настройки для виртуальных доменов и почтовых ящиков:

       - `virtual_mailbox_domains = virtual.otus` — перечисление виртуальных доменов, для которых будет приниматься почта;
       - `virtual_mailbox_base = /var/spool/mail/vhosts` — базовый путь (префикс), где будут лежать почтовые ящики;
       - `virtual_mailbox_maps = hash:/etc/postfix/vmailbox` — путь до файла, где будут прописаны названия виртуальных почтовых ящиков и соответствующие им относительные пути до почтовых хранилищ;
       - `virtual_minimum_uid = 100` — минимальный uid, который может иметь владелец почтовых хранилищ (введен для повышения безопасности);
       - `virtual_uid_maps = static:5000` — uid владельца всех виртуальных почтовых хранилищ;
       - `virtual_gid_maps = static:5000` — gid владельца всех виртуальных почтовых хранилищ;
       - дополнительно может быть указан параметр `virtual_alias_maps = hash:/etc/postfix/virtual` — путь до файла, в котором могут храниться синонимы для перенаправления почты между доменами. В данной работе не используется.

   - В каталог **/etc/postfix** копируется файл [vmailbox](provisioning/roles/mail/templates/vmailbox.j2) c названиями почтовых ящиков и относительными путями до почтовых хранилищ:

        ```
        student@virtual.otus virtual.otus/student/
        teacher@virtual.otus virtual.otus/teacher/
        manager@virtual.otus virtual.otus/manager/
        ```

        Абсолютный путь до почтового хранилища собирается из базового пути (заданного в параметре `virtual_mailbox_base`) и относительного пути. Таким орбазом, полный путь до почтового хранилища ящика student@vitual.otus следующий: /var/spool/mail/vhosts/virtual.otus/student. 

   - Выполняется команда:

        ```
        postmap /etc/postfix/vmailbox
        ```

        В результате в каталоге **/etc/postfix** создаётся файл **vmailbox.db**, который и будет использоваться postfix'ом.

5. Postfix перезапускается.
6. В файлы конфигурирования dovecot вносятся изменения:

   - **/etc/dovecot/dovecot.conf** — раскомментируются строки:

        ```
        protocols = imap pop3 lmtp
        listen = *
        ```

   - **/etc/dovecot/conf.d/10-auth.conf**:

        ```
        disable_plaintext_auth = no
        auth_mechanisms = plain login
        !include auth-passwdfile.conf.ext
        ```

   - **/etc/dovecot/conf.d/10-ssl.conf**:

        ```
        ssl = no
        ```

   - **/etc/dovecot/conf.d/10-mail.conf**:

        ```
        mail_location = mailbox:/var/spool/mail/vhosts/virtual.otus/%u
        ```



### Проверка работы



#### Отправка почты



#### Получение почты



<br/>

[Вернуться к списку всех ДЗ](../README.md)
