## Домашнее задание к занятию № 17 — «Резервное копирование»    <!-- omit in toc -->

### Оглавление  <!-- omit in toc -->

- [Задание](#Задание)
- [Описание работы](#Описание-работы)
- [Проверка работы](#Проверка-работы)
  - [Снятие бэкапа по расписанию](#Снятие-бэкапа-по-расписанию)
  - [Восстановление из бэкапа](#Восстановление-из-бэкапа)

### Задание

Снятие бэкапов с помощью BorgBackup.

Настроить стенд Vagrant с двумя виртуальными машинами: server и backup.

Настроить политику бэкапа директории **/etc** с клиента (server) на бэкап-сервер (backup):
1. Бэкап снимается раз в час.
2. Политика хранения бэкапов: хранятся все за последние 30 дней, и по одному за предыдущие два месяца.
3. Процесс бэкапа логируется в **/var/log/**.
4. Восстановить из бэкапа директорию **/etc** с помощью команды `borg mount`.

Результатом должен быть скрипт резервного копирования (политику хранения можно реализовать в нём же), а также вывод команд терминала.

Задание со *: настроить репозиторий для резервных копий с шифрованием ключом.

### Описание работы

При выполнении команды `vagrant up` поднимаются две виртуальные машины — server и backup, после чего запускается их настройка посредством Ansible.

Так как необходимо снимать резервные копии каталога **/etc**, запуск Borg производится из-под пользователя root.

Шаги предварительной настройки:

1. На обеих машинах устанавливается Borg — из официального репозитория скачивается бинарный файл и сохраняется в каталог **/bin**, ему выдаются права на выполнение (0755).
    
    > *Примечание*. Если скопировать файл в каталог **/usr/local/bin**, как это указано на официальном сайте, то запуск программы через Ansible вызовет ошибку, так как этого каталога нет в переменной `$PATH` пользователя root, из-под которого и выполняется плейбук (не помогает даже использование ключа `become_user`).

2. Для пользователя root на клиенте (машина server) генерируется пара SSH-ключей.
3. Открытый SSH-ключ копируется в файл **authorized_keys** на машине backup для доступа по SSH. Также для этого пользователя на клиенте создаётся [SSH config](provisioning/roles/deploy_key/templates/config.j2).
4. На бэкар-сервере создаётся директория для хранения бэкапов: **/opt/backups/files-etc**.
5. На клиенте выполняется команда инициализации удалённого репозитория с использованием шифрования (ключевая фраза задаётся в [стартовом плейбуке](provisioning/start.yml) и передаётся через переменную окружения `BORG_NEW_PASSPHRASE`). Если репозиторий уже существует (проверяется по наличию каталога **data** в директории для хранения бэкапов), этот шаг пропускается.
6. Параметризированный скрипт для снятия бэкапа [borg-etc.sh](provisioning/roles/run_borg/templates/borg-etc.sh.j2) копируется в каталог **/opt** на клиенте, ему выдаются права на выполнение.

    В скрипте задаётся нужная политика хранения бэкапов при помощи ключей команды `borg prune`: `--keep-within 30d` и `--keep-monthly 2`.

    Здесь же настраивается логирование работы скрипта в файл **/var/log/borg.log**. Для этого задано перенаправление вывода команд `borg create` и `borg prune` в нужный файл (по умолчанию Borg выводит всю информацию в stderr): `borg create [options] 2>> /var/log/borg.log`. Уровень логирования задаётся ключами этих команд, в данной работе используется `--verbose` (соответствует уровню логирования INFO).

    Кроме вывода команд, в файле лога фиксируются этапы работы Borg. При ручном запуске скрипта эта информация выводится также в консоль:

    ```bash
    info() { printf "#### %s %s ####\n" "$( date )" "$*" | tee -a /var/log/borg.log; }
    ...
    info "Starting backup"
    ```

7. В Cron настраивается выполнение скрипта каждый час:

    ```console
    [root@server ~]# crontab -l
    #Ansible: Create backup with Borg
    @hourly /opt/borg-etc.sh > /dev/null 2>&1
    ```

### Проверка работы

Чтобы создать и сконфигурировать все машины, достаточно выполнить команду `vagrant up`.

Проверка произодится на виртуальной машине server под пользователем root.

#### Снятие бэкапа по расписанию

Для проверки настроим запуск снятия бэкапа с большей частотой, например, каждые 10 минут:

```
#Ansible: Create backup with Borg
*/10 * * * * /opt/borg-etc.sh > /dev/null 2>&1
```

Подождём некоторое время и при помощи команды `borg list` проверим, что резерные копии создаются. Так как мы используем шифрование, от нас потребуется ввести ключевую фразу. В данной работе это `qwerty123` (задаётся в [стартовом плейбуке](provisioning/start.yml)):

```console
[root@server ~]# borg list root@backup:/opt/backups/files-etc
Enter passphrase for key ssh://root@backup/opt/backups/files-etc: 
2020-05-16_23:30                     Sat, 2020-05-16 23:30:05 [91a123b2f9a759f9d226abde1262360f0c5dfb1b98219c88d804f211327777db]
2020-05-16_23:40                     Sat, 2020-05-16 23:40:03 [3fbce82e71b5170ace4cc5a281f434622b275c469ef59260c532753e74cdacfd]
2020-05-16_23:50                     Sat, 2020-05-16 23:50:03 [adad3378b196a82336922353143a5d8770b79ebb1431c822180cf04e1eab00cf]
2020-05-17_00:00                     Sun, 2020-05-17 00:00:03 [bec6f0fe64adc9ac2eef43dc13278d317f66f9d79b26ccce9f1f1311417a73e7]
```

Проверим содержимое лога:

```console
[root@server ~]# tail -35 /var/log/borg.log
#### Sun May 17 00:00:01 UTC 2020 Starting backup ####
Creating archive at "root@backup:/opt/backups/files-etc::2020-05-17_00:00"
A /etc/resolv.conf
------------------------------------------------------------------------------
Archive name: 2020-05-17_00:00
Archive fingerprint: bec6f0fe64adc9ac2eef43dc13278d317f66f9d79b26ccce9f1f1311417a73e7
Time (start): Sun, 2020-05-17 00:00:03
Time (end):   Sun, 2020-05-17 00:00:04
Duration: 0.40 seconds
Number of files: 1688
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:               27.79 MB             13.26 MB                679 B
All archives:              111.17 MB             53.05 MB             11.75 MB

                       Unique chunks         Total chunks
Chunk index:                    1278                 6736
------------------------------------------------------------------------------
terminating with success status, rc 0
#### Sun May 17 00:00:04 UTC 2020 Pruning repository ####
Keeping archive: 2020-05-17_00:00                     Sun, 2020-05-17 00:00:03 [bec6f0fe64adc9ac2eef43dc13278d317f66f9d79b26ccce9f1f1311417a73e7]
Keeping archive: 2020-05-16_23:50                     Sat, 2020-05-16 23:50:03 [adad3378b196a82336922353143a5d8770b79ebb1431c822180cf04e1eab00cf]
Keeping archive: 2020-05-16_23:40                     Sat, 2020-05-16 23:40:03 [3fbce82e71b5170ace4cc5a281f434622b275c469ef59260c532753e74cdacfd]
Keeping archive: 2020-05-16_23:30                     Sat, 2020-05-16 23:30:05 [91a123b2f9a759f9d226abde1262360f0c5dfb1b98219c88d804f211327777db]
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
Deleted data:                    0 B                  0 B                  0 B
All archives:              111.17 MB             53.05 MB             11.75 MB

                       Unique chunks         Total chunks
Chunk index:                    1278                 6736
------------------------------------------------------------------------------
terminating with success status, rc 0
#### Sun May 17 00:00:06 UTC 2020 Backup and Prune finished successfully ####
```

#### Восстановление из бэкапа

Удалим из каталога **/etc** какой-нибудь файл, например, **crontab**:

```console
[root@server ~]# rm -f /etc/crontab 
[root@server ~]# cat /etc/crontab
cat: /etc/crontab: No such file or directory
```

Проверим список бэкапов (кодовая фраза — `qwerty123`):

```console
[root@server ~]# borg list root@backup:/opt/backups/files-etc
Enter passphrase for key ssh://root@backup/opt/backups/files-etc: 
2020-05-16_23:30                     Sat, 2020-05-16 23:30:05 [91a123b2f9a759f9d226abde1262360f0c5dfb1b98219c88d804f211327777db]
2020-05-16_23:40                     Sat, 2020-05-16 23:40:03 [3fbce82e71b5170ace4cc5a281f434622b275c469ef59260c532753e74cdacfd]
2020-05-16_23:50                     Sat, 2020-05-16 23:50:03 [adad3378b196a82336922353143a5d8770b79ebb1431c822180cf04e1eab00cf]
2020-05-17_00:00                     Sun, 2020-05-17 00:00:03 [bec6f0fe64adc9ac2eef43dc13278d317f66f9d79b26ccce9f1f1311417a73e7]
```

Создадим точку монтирования для Borg:

```console
[root@server ~]# mkdir /mnt/borg
```

Примонтируем к ней последний архив из списка:

```console
[root@server ~]# borg mount root@backup:/opt/backups/files-etc::2020-05-17_00:00 /mnt/borg
Enter passphrase for key ssh://root@backup/opt/backups/files-etc:
[root@server ~]# ls /mnt/borg
etc
```

Скопируем удалённый файл из примонтированного архива в каталог **/etc**:

```console
[root@server ~]# cp /mnt/borg/etc/crontab /etc/
[root@server ~]# cat /etc/crontab 
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root

# For details see man 4 crontabs

# Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name  command to be executed
```

Отмонтируем архив:

```console
[root@server ~]# borg umount /mnt/borg
[root@server ~]# ls -l /mnt/borg/
total 0
```

<br/>

[Вернуться к списку всех ДЗ](../README.md)
