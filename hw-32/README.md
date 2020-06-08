## Домашнее задание к занятию № 32 — «MySQL»    <!-- omit in toc -->

### Оглавление  <!-- omit in toc -->

- [Задание](#задание)
- [Описание работы](#описание-работы)
  - [Настройка машины master](#настройка-машины-master)
  - [Настройка машины slave](#настройка-машины-slave)
- [Проверка работы](#проверка-работы)

### Задание

Развернуть на мастере базу bet из дампа и настроить репликацию таблиц:
  - bookmaker;
  - competition;
  - market;
  - odds;
  - outcome.

Задание со *: настроить GTID-репликацию.

### Описание работы

При выполнении команды `vagrant up` поднимаются две виртуальные машины — master и slave ([Vagrantfile](Vagrantfile)), которые конфигурируются при помощи Ansible.

#### Настройка машины master

1. Устанавливается Percona Server for MySQL:
   - устанавливается репозиторий Percona;
   - устанавливается Percona server, а также библиотека MySQL-python для управления базами данных при помощи Ansible;
   - в каталог **/etc/my.cnf.d/** копируются параметризированные [файлы конфигурации MySQL](provisioning/roles/mysql-install/templates/my.cnf.d). Для работы GTID-репликации необходимы следующие параметры:
     - `server-id = 1` — уникальный номер для каждого хоста;
     - `log-bin = mysql-bin` — указывает местоположение двоичного журнала (binary log) обновлений;
     - `gtid-mode = On` — включение режима GTID;
     - `enforce-gtid-consistency = On` — позволяет выполнять только те операции, которые могут быть записаны в лог с GTID;
     - `log-slave-updates = On` — включает запись обновлений на подчинённом сервере при репликации в двоичном журнале.

   - запускается служба mysql.

2. В MySQL задаётся пароль для пользователя root. Для этого производится проверка на наличие файла **/root/.my.cnf**. Если файла нет, то из файла **/var/log/mysqld.log** считывается временный пароль, созданный автоматически, который используется для установки постоянного пароля, определённого в файле [secrets.yml](provisioning/secrets.yml). После этого на сервере создаётся файл **/root/.my.cnf**, куда сохраняется постоянный пароль и который используется для входа в MySQL.
3. В каталог **/opt** копируется [дамп базы данных bet](provisioning/roles/init-master/files/bet.dmp).
4. База данных bet разворачивается из дампа.
5. Создаётся пользователь repl для репликации, ему выдаются соответствующие разрешения. Логин и пароль пользователя для репликации задаются в файле [secrets.yml](provisioning/secrets.yml).

#### Настройка машины slave

1. Так же, как и на мастере, устанавливаются Percona server и MySQL-python и задаётся пароль пользователя root (используется та же роль [mysql-install](provisioning/roles/mysql-install)). При этом в конфигурационных файлах MySQL есть отличия:
   - изменён ID сервера: `server-id = 2`;
   - заданы таблицы, не предназначенные для репликации:
    
     ```
     replicate-ignore-table = bet.events_on_demand
     replicate-ignore-table = bet.v_same_event
     ```

2. Влючается репликация: устанавливаются параметры для подключения к мастеру и запускается поток подчинённого сервера.

### Проверка работы

Зайдём на машину slave и просмотрим информацию о состоянии потока подчиненного сервера:

```console
mysql> show slave status\G
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 192.168.11.150
                  Master_User: repl
                  Master_Port: 3306
...
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
...
       Replicate_Ignore_Table: bet.events_on_demand,bet.v_same_event
...
           Retrieved_Gtid_Set: f2f75e34-a904-11ea-82bc-5254004d77d3:1-39
            Executed_Gtid_Set: 68ec418a-a905-11ea-8772-5254004d77d3:1,
f2f75e34-a904-11ea-82bc-5254004d77d3:1-39
...
```

Убедимся, что таблица bet скопирована с мастера и что в ней нет таблиц, не предназначенных для репликации:

```console
mysql> show databases like 'bet';
+----------------+
| Database (bet) |
+----------------+
| bet            |
+----------------+
1 row in set (0.00 sec)

mysql> use bet;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> show tables;
+---------------+
| Tables_in_bet |
+---------------+
| bookmaker     |
| competition   |
| market        |
| odds          |
| outcome       |
+---------------+
5 rows in set (0.00 sec)

mysql> select * from bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
4 rows in set (0.00 sec)
```

Добавим на мастере запись в таблицу bookmaker:

```console
mysql>  INSERT INTO bet.bookmaker (id,bookmaker_name) VALUES (1,'custom_name');
Query OK, 1 row affected (0.02 sec)

mysql> select * from bet.bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  4 | betway         |
|  5 | bwin           |
|  1 | custom_name    |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)
```

Убедимся, что созданная запись появилась на slave:

```console
mysql> select * from bookmaker;
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  4 | betway         |
|  5 | bwin           |
|  1 | custom_name    |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
5 rows in set (0.00 sec)
```

Проверим записи в двоичном журнале на slave:

```console
mysql> show master logs;
+------------------+-----------+
| Log_name         | File_size |
+------------------+-----------+
| mysql-bin.000001 |       177 |
| mysql-bin.000002 |       421 |
| mysql-bin.000003 |    113962 |
+------------------+-----------+
3 rows in set (0.00 sec)

mysql> show binlog events in 'mysql-bin.000003'\G
...
*************************** 101. row ***************************
   Log_name: mysql-bin.000003
        Pos: 113661
 Event_type: Gtid
  Server_id: 1
End_log_pos: 113726
       Info: SET @@SESSION.GTID_NEXT= 'f2f75e34-a904-11ea-82bc-5254004d77d3:40'
*************************** 102. row ***************************
   Log_name: mysql-bin.000003
        Pos: 113726
 Event_type: Query
  Server_id: 1
End_log_pos: 113796
       Info: BEGIN
*************************** 103. row ***************************
   Log_name: mysql-bin.000003
        Pos: 113796
 Event_type: Query
  Server_id: 1
End_log_pos: 113931
       Info: INSERT INTO bet.bookmaker (id,bookmaker_name) VALUES (1,'custom_name')
*************************** 104. row ***************************
   Log_name: mysql-bin.000003
        Pos: 113931
 Event_type: Xid
  Server_id: 1
End_log_pos: 113962
       Info: COMMIT /* xid=73 */
104 rows in set (0.00 sec)
```

<br/>

[Вернуться к списку всех ДЗ](../README.md)
