## Домашнее задание к занятию № 29 — «PostgreSQL»  <!-- omit in toc -->

### Оглавление  <!-- omit in toc -->

- [Задание](#задание)
- [Описание работы](#описание-работы)
  - [Общая информация](#общая-информация)
  - [Настройка машины master](#настройка-машины-master)
  - [Настройка машины slave](#настройка-машины-slave)
  - [Настройка машины backup](#настройка-машины-backup)
- [Проверка работы](#проверка-работы)
  - [Проверка потоковой репликации](#проверка-потоковой-репликации)
  - [Проверка резервного копирования](#проверка-резервного-копирования)

### Задание

- Настроить hot_standby репликацию с использованием слотов.
- Настроить резервное копирование.

### Описание работы

#### Общая информация

В работе настраивается потоковая репликация между двумя серверами, один из которых является ведущим, а другой ведомым. В работе репликации используются слоты.

Резервное копирование реализовано посредством программы [Barman](https://www.pgbarman.org/), установленной на третий сервер. Резервное копирование также осуществляется при помощи потоковой репликации со слотами.

При выполнении команды `vagrant up` поднимаются три виртуальные машины: master, slave и backup ([Vagrantfile](Vagrantfile)), которые конфигурируются при помощи Ansible.

Для каждой машины написан свой стартовый плейбук. Все плейбуки находятся в каталоге [playbooks](provisioning/playbooks). 

Чувствительные к окружению переменные (логины, пароли и адреса хостов) заданы в файлах **defaults/main.yml** в соответствующих ролях и могут быть переопределены в файле [vars.yml](provisioning/vars.yml), на который ссылаются все плейбуки.

#### Настройка машины master

[Ссылка на стартовый плейбук](provisioning/playbooks/master.yml)

Установка и первичная настройка PostgreSQL (роль [pgsql-install](provisioning/roles/pgsql-install)):

1. Устанавливается репозиторий PostgreSQL, из которого устанавливается сервер БД.
2. Сервер PostgreSQL инициализируется, запускается и добавляется в автозагрузку.
3. Устанавливается репозиторий EPEL, устанавливается и обновляется до последней версии менеджер пакетов pip, с его помощью загружается библиотека psycopg2 для управления PostgreSQL посредством Ansible.
4. Загружается библиотека libsemanage-python для управления SELinux посредством Ansible. В SELinux включается правило для разрешения удалённых подключений к серверу PostgreSQL.
5. Для роли postgres задаётся пароль в кластере PostgreSQL. Этот пароль записывается в файл [.pgpass](provisioning/roles/pgsql-install/templates/postgres_pgpass.j2), который, в свою очередь, копируется на сервер в домашний каталог пользователя postgres (**/var/lib/pgsql**).
6. На сервер копируется файл [postgresql.conf](provisioning/roles/pgsql-install/files/postgresql.conf), в который внесены дополнительные настройки согласно инструменту: https://pgtune.leopard.in.ua/

    Заданы следующие параметры (для сервера с 1 Гб RAM):

    ```
    listen_addresses = '*'
    port = 5432
    max_connections = 100
    shared_buffers = 256MB
    work_mem = 1310kB
    maintenance_work_mem = 64MB
    effective_io_concurrency = 2
    fsync = on
    wal_buffers = 7864kB
    max_wal_size = 4GB
    min_wal_size = 1GB
    checkpoint_completion_target = 0.7
    effective_cache_size = 768MB
    default_statistics_target = 100
    autovacuum = on
    ```

7. На сервер копируется файл [pg_hba.conf](provisioning/roles/pgsql-install/files/pg_hba.conf), в котором настроен доступ с любого узла по паролю.
8. После изменения файлов **postgresql.conf** и **pg_hba.conf** сервер PostgreSQL перезапускается.

Настройка мастера для репликации (роль [pgsql-replica-master](provisioning/roles/pgsql-replica-master)):

1. В кластере создаётся роль для репликации, ей задаётся пароль, эти данные добавляются в файл **.pgpass** в домашнем каталоге пользователя postgres.
2. В файл **pg_hba.conf** вносится настройка, открывающая для роли репликации доступ к ведущему серверу с ведомого:

    ```
    host  replication  repluser  10.10.10.20/32  md5
    ```

    Изменения в файл **pg_hba.conf** вносятся при помощи модуля lineinfile, а не copy или template, для того, чтобы обеспечить независимость друг от друга ролей для настройки репликации и резервного копирования. 

3. На сервер копируется файл [postgresql.conf](provisioning/roles/pgsql-replica-master/files/postgresql.conf), в который внесены дополнительные настройки для потоковой репликации:

    ```
    wal_level = replica
    max_wal_senders = 5
    wal_keep_segments = 1000
    max_replication_slots = 5
    ```

4. Создаётся слот для репликации, если он отсутствует. Запрос для создания слота:

    ```sql
    SELECT * FROM pg_create_physical_replication_slot('node_a_slot');
    ```

5. После изменения файлов **postgresql.conf** и **pg_hba.conf** сервер PostgreSQL перезапускается.

Настройка мастера для резервного копирования (роль [barman-master](provisioning/roles/barman-master)):

1. В кластере создаются роль barman с правами суперпользователя и роль streaming_barman для репликации, им задаются пароли.
2. В файл **pg_hba.conf** вносится настройка, открывающая для роли репликации доступ к БД-серверу с сервера резервного копирования:

    ```
    host  replication  streaming_barman  10.10.10.30/32  md5
    ```

    Изменения в файл **pg_hba.conf** вносятся при помощи модуля lineinfile, а не copy или template, для того, чтобы обеспечить независимость друг от друга ролей для настройки репликации и резервного копирования.

    Отдельная настройка для роли barman не задаётся, так как в текущей конфигурации разрешено подключение любого пользователя с любого хоста (при наличии пароля):

    ```
    host  all  all  0.0.0.0/0  md5
    ```

3. На сервер копируется файл [postgresql.conf](provisioning/roles/barman-master/files/postgresql.conf), идентичный файлу в роли для настройки репликации.
4. После изменения файлов **postgresql.conf** и **pg_hba.conf** сервер PostgreSQL перезапускается.

Итоговый файл **postgresql.conf** можно посмотреть либо в роли [pgsql-replica-master](provisioning/roles/pgsql-replica-master/files/postgresql.conf), либо в роли [barman-master](provisioning/roles/barman-master/files/postgresql.conf).

Итоговый файл **pg_hba.conf** без комментариев и пустых строк выглядит следующим образом:

```console
[root@master ~]# cat /var/lib/pgsql/11/data/pg_hba.conf | egrep -v '^#|^$'
local   all             all                                     md5
host    all             all             0.0.0.0/0            md5
local   replication     all                                     md5
host    replication     repluser             10.10.10.20/32            md5
host    replication     streaming_barman     10.10.10.30/32            md5
```

#### Настройка машины slave

[Ссылка на стартовый плейбук](provisioning/playbooks/slave.yml)

Установка и первичная настройка PostgreSQL (роль [pgsql-install](provisioning/roles/pgsql-install)) выполняется точно так же, как и на мастере.

Настройка слейва для репликации (роль [pgsql-replica-slave](provisioning/roles/pgsql-replica-slave)):

1. Останавливается работа сервера PostgreSQL.
2. Логин и пароль роли для репликации добавляются в файл **.pgpass** в домашнем каталоге пользователя postgres.
3. Все файлы кластера (каталог **/var/lib/pgsql/11/data**) удаляются.
4. При помощи команды `pg_basebackup` создаётся полная копия кластера с ведущего сервера. Также при её выполнении автоматически создаётся файл **recovery.conf**. Полный синтаксис команды выглядит следующим образом:

    ```console
    pg_basebackup -h 10.10.10.10 -U repluser -D /var/lib/pgsql/11/data/ -X stream -S node_a_slot -R
    ```

5. В файл **pg_hba.conf** вносится настройка, открывающая для роли репликации доступ к ведомому серверу с ведущего:

    ```
    host  replication  repluser  10.10.10.10/32  md5
    ```

6. На сервер копируется файл [postgresql.conf](provisioning/roles/pgsql-replica-slave/files/postgresql.conf), который идентичен этому файлу на ведущем сервере за исключением одного параметра:

    ```
    hot_standby = on
    ```

7. После изменения файлов **postgresql.conf** и **pg_hba.conf** сервер PostgreSQL перезапускается.

Итоговый файл **postgresql.conf** можно посмотреть в роли [pgsql-replica-slave](provisioning/roles/pgsql-replica-slave/files/postgresql.conf).

Итоговый файл **pg_hba.conf** без комментариев и пустых строк выглядит следующим образом:

```console
[root@slave ~]# cat /var/lib/pgsql/11/data/pg_hba.conf | egrep -v '^#|^$'
local   all             all                                     md5
host    all             all             0.0.0.0/0            md5
local   replication     all                                     md5
host    replication     repluser             10.10.10.20/32            md5
host    replication     streaming_barman     10.10.10.30/32            md5
host    replication     repluser             10.10.10.10/32            md5
```

Итоговый файл **recovery.conf** без комментариев и пустых строк выглядит следующим образом:

```console
[root@slave ~]# cat /var/lib/pgsql/11/data/recovery.conf | egrep -v '^#|^$'
standby_mode = 'on'
primary_conninfo = 'user=repluser passfile=''/var/lib/pgsql/.pgpass'' host=10.10.10.10 port=5432 sslmode=prefer sslcompression=0 krbsrvname=postgres target_session_attrs=any'
primary_slot_name = 'node_a_slot'
```

#### Настройка машины backup

[Ссылка на стартовый плейбук](provisioning/playbooks/backup.yml)

Настройка резервного копирования (роль [barman-backup](provisioning/roles/barman-backup)):

1. Устанавливается репозиторий PostgreSQL, из которого устанавливается клиент postgresql.
2. Устанавливается репозиторий EPEL, из которого устанавливается Barman.
3. В домашний каталог пользователя barman (**/var/lib/barman**) копируется файл [.pgpass](provisioning/roles/barman-backup/templates/barman_pgpass.j2), в котором заданы логины и пароли ролей barman и streaming_barman.
4. На сервер копируются файл конфигурации [barman.conf](provisioning/roles/barman-backup/templates/barman.conf.j2) и файл настройки резервного копирования [pg.conf](provisioning/roles/barman-backup/templates/pg.conf.j2).
5. Потоковая архивация запускается автоматически, однако WAL-файлы при первоначальном запуске могут собираться некорректно. Для того, чтобы исправить эту ошибку (при её наличии), от имени пользователя barman выполняется следующая команда:

    ```console
    barman switch-wal --force --archive pg
    ```

    Подробнее об этом можно прочитать в документации: http://docs.pgbarman.org/release/2.11/#verification-of-wal-archiving-configuration

    При выполнении через Ansible эта команда при первом прогоне по какой-то причине возвращает код ошибки, поэтому таск с ней выполняется циклично до успешного завершения.

6. Для пользователя barman создаётся пара SSH-ключей. Открытый ключ записывается в файл authorized_keys пользователя postgres на сервере master, чтобы Barman имел возможность подключаться к мастеру по SSH и восстанавливать БД из бэкапа.

Итоговый файл **barman.conf** без комментариев и пустых строк выглядит следующим образом:

```console
[root@backup ~]# cat /etc/barman.conf | egrep -v '^;|^$'
[barman]
barman_user = barman
configuration_files_directory = /etc/barman.d
barman_home = /var/lib/barman
log_file = /var/log/barman/barman.log
log_level = INFO
compression = gzip
```

Итоговый файл **pg.conf** без комментариев и пустых строк выглядит следующим образом:

```console
[root@backup ~]# cat /etc/barman.d/pg.conf | egrep -v '^;|^$'
[pg]
description = "Our main PostgreSQL server"
conninfo = host=10.10.10.10 user=barman dbname=postgres
streaming_conninfo = host=10.10.10.10 user=streaming_barman dbname=postgres
backup_method = postgres
streaming_archiver = on
slot_name = barman
create_slot = auto
path_prefix = "/usr/pgsql-11/bin"
```

### Проверка работы

Чтобы создать и настроить виртуальные машины, достаточно выполнить команду `vagrant up`.

#### Проверка потоковой репликации

Зайдём на машину master, залогинимся под пользователем postges, запустим консольный клиент psql и проверим статистику о репликации:

```console
[vagrant@master ~]$ sudo su - postgres
-bash-4.2$ psql
psql (11.8)
Type "help" for help.

postgres=# \x
Expanded display is on.
postgres=# select * from pg_stat_replication;
-[ RECORD 1 ]----+------------------------------
pid              | 5963
usesysid         | 16384
usename          | repluser
application_name | walreceiver
client_addr      | 10.10.10.20
client_hostname  | 
client_port      | 34216
backend_start    | 2020-07-24 17:55:21.666312+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/5000140
write_lsn        | 0/5000140
flush_lsn        | 0/5000140
replay_lsn       | 0/5000140
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
-[ RECORD 2 ]----+------------------------------
pid              | 5971
usesysid         | 16386
usename          | streaming_barman
application_name | barman_receive_wal
client_addr      | 10.10.10.30
client_hostname  | 
client_port      | 51824
backend_start    | 2020-07-24 17:58:02.853655+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/5000140
write_lsn        | 0/5000140
flush_lsn        | 0/5000000
replay_lsn       | 
write_lag        | 00:00:09.588237
flush_lag        | 00:14:19.216055
replay_lag       | 00:14:33.718757
sync_priority    | 0
sync_state       | async

postgres=# \x
Expanded display is off.
```

Первая запись соответствует ведомому серверу slave, вторая ­— серверу резервного копирования backup.

Проверим созданные слоты:

```console
postgres=# SELECT slot_name, slot_type, active FROM pg_replication_slots;
  slot_name  | slot_type | active 
-------------+-----------+--------
 node_a_slot | physical  | t
 barman      | physical  | t
(2 rows)
```

Создадим новую базу данных и таблицу в ней:

```console
postgres=# create database otus;
CREATE DATABASE
postgres=# \c otus
You are now connected to database "otus" as user "postgres".
otus=# create table students(id serial, name varchar);
CREATE TABLE
otus=# insert into students(name) values ('Alex'),('Anna'),('John');
INSERT 0 3
otus=# select * from students;
 id | name 
----+------
  1 | Alex
  2 | Anna
  3 | John
(3 rows)
```

Теперь зайдём на машину slave, также под пользователем postgres откроем psql и проверим статистику приёмника WAL:

```console
[vagrant@slave ~]$ sudo su - postgres
-bash-4.2$ psql
psql (11.8)
Type "help" for help.

postgres=# \x
Expanded display is on.
postgres=# select * from pg_stat_wal_receiver;
-[ RECORD 1 ]---------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
pid                   | 5599
status                | streaming
receive_start_lsn     | 0/3000000
receive_start_tli     | 1
received_lsn          | 0/50200E8
received_tli          | 1
last_msg_send_time    | 2020-07-24 18:25:22.974586+00
last_msg_receipt_time | 2020-07-24 18:25:22.974966+00
latest_end_lsn        | 0/50200E8
latest_end_time       | 2020-07-24 18:22:52.706844+00
slot_name             | node_a_slot
sender_host           | 10.10.10.10
sender_port           | 5432
conninfo              | user=repluser passfile=/var/lib/pgsql/.pgpass dbname=replication host=10.10.10.10 port=5432 fallback_application_name=walreceiver sslmode=prefer sslcompression=0 krbsrvname=postgres target_session_attrs=any

postgres=# \x
Expanded display is off.
```

Убедимся, что созданные на мастере база данных и таблица отображаются и на реплике:

```console
postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 otus      | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | 
 template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(4 rows)

postgres=# \c otus
You are now connected to database "otus" as user "postgres".
otus=# select * from students;
 id | name 
----+------
  1 | Alex
  2 | Anna
  3 | John
(3 rows)
```

#### Проверка резервного копирования

Зайдём на машину backup, залогинимся под пользователем barman и проверим состояние текущей конфигурации:

```console
[vagrant@backup ~]$ sudo su - barman
-bash-4.2$ barman check pg
Server pg:
        PostgreSQL: OK
        superuser or standard user with backup privileges: OK
        PostgreSQL streaming: OK
        wal_level: OK
        replication slot: OK
        directories: OK
        retention policy settings: OK
        backup maximum age: OK (no last_backup_maximum_age provided)
        compression settings: OK
        failed backups: OK (there are 0 failed backups)
        minimum redundancy requirements: OK (have 0 backups, expected at least 0)
        pg_basebackup: OK
        pg_basebackup compatible: OK
        pg_basebackup supports tablespaces mapping: OK
        systemid coherence: OK (no system Id stored on disk)
        pg_receivexlog: OK
        pg_receivexlog compatible: OK
        receive-wal running: OK
        archiver errors: OK
```

Снимем бэкап:

```console
-bash-4.2$ barman backup -w pg
Starting backup using postgres method for server pg in /var/lib/barman/pg/base/20200724T184200
Backup start at LSN: 0/50200E8 (000000010000000000000005, 000200E8)
Starting backup copy via pg_basebackup for 20200724T184200
Copy done (time: less than one second)
Finalising the backup.
This is the first backup for server pg
WAL segments preceding the current backup have been found:
        000000010000000000000004 from server pg has been removed
Backup size: 30.1 MiB
Backup end at LSN: 0/7000000 (000000010000000000000006, 00000000)
Backup completed (start time: 2020-07-24 18:42:01.106690, elapsed time: less than one second)
Waiting for the WAL file 000000010000000000000006 from server 'pg'
Processing xlog segments from streaming for pg
        000000010000000000000005
Processing xlog segments from streaming for pg
        000000010000000000000006
```

Посмотрим информацию о снятом бэкапе:

```console
-bash-4.2$ barman list-backup pg
pg 20200724T184200 - Fri Jul 24 18:42:01 2020 - Size: 30.1 MiB - WAL Size: 0 B
-bash-4.2$ barman show-backup pg 20200724T184200 
Backup 20200724T184200:
  Server Name            : pg
  System Id              : 6853105947377438107
  Status                 : DONE
  PostgreSQL Version     : 110008
  PGDATA directory       : /var/lib/pgsql/11/data

  Base backup information:
    Disk usage           : 30.1 MiB (30.1 MiB with WALs)
    Incremental size     : 30.1 MiB (-0.00%)
    Timeline             : 1
    Begin WAL            : 000000010000000000000006
    End WAL              : 000000010000000000000006
    WAL number           : 1
    WAL compression ratio: 99.90%
    Begin time           : 2020-07-24 18:42:01+00:00
    End time             : 2020-07-24 18:42:01.850655+00:00
    Copy time            : less than one second
    Estimated throughput : 41.0 MiB/s
    Begin Offset         : 40
    End Offset           : 0
    Begin LSN           : 0/6000028
    End LSN             : 0/7000000

  WAL information:
    No of files          : 0
    Disk usage           : 0 B
    Last available       : 000000010000000000000006

  Catalog information:
    Retention Policy     : not enforced
    Previous Backup      : - (this is the oldest base backup)
    Next Backup          : - (this is the latest base backup)
```

Зайдём на мастер и внесём изменения в таблицу students:

```console
otus=# delete from students where id = 3;
DELETE 1
otus=# update students set name = 'Kate' where id = 2;
UPDATE 1
otus=# select * from students;
 id | name 
----+------
  1 | Alex
  2 | Kate
(2 rows)
```

Восстановление бэкапа невозможно при запущенной службе PostgreSQL. Залогинимся под пользователем root и остановим её:

```console
[root@master ~]# systemctl stop postgresql-11
```

На машине backup выполним команду восстановления из бэкапа:

```console
-bash-4.2$ barman recover --remote-ssh-command "ssh postgres@10.10.10.10" pg 20200724T184200 /var/lib/pgsql/11/data
The authenticity of host '10.10.10.10 (10.10.10.10)' can't be established.
ECDSA key fingerprint is SHA256:JNPBZQ4j075iog62/jYRthnQK4a0evhJwCBNy4Tq3EA.
ECDSA key fingerprint is MD5:c2:30:52:cf:f7:07:10:0f:1b:9b:d4:3f:62:1e:45:77.
Are you sure you want to continue connecting (yes/no)? yes
Starting remote restore for server pg using backup 20200724T184200
Destination directory: /var/lib/pgsql/11/data
Remote command: ssh postgres@10.10.10.10
Copying the base backup.
Copying required WAL segments.
Generating archive status files
Identify dangerous settings in destination directory.

Recovery completed (start time: 2020-07-24 18:52:29.213374, elapsed time: 9 seconds)

Your PostgreSQL server has been successfully prepared for recovery!
```

На мастере запустим сервер PostgreSQL и убедимся, что данные восстановлены:

```console
[root@master ~]# systemctl start postgresql-11
[root@master ~]# su - postgres
-bash-4.2$ psql
psql (11.8)
Type "help" for help.

postgres=# \c otus
You are now connected to database "otus" as user "postgres".
otus=# select * from students;
 id | name 
----+------
  1 | Alex
  2 | Anna
  3 | John
(3 rows)
```

<br/>

[Вернуться к списку всех ДЗ](../README.md)
