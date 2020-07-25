## Домашнее задание к занятию № 36 — «Файловые хранилища — NFS, SMB, FTP»  <!-- omit in toc -->

### Оглавление  <!-- omit in toc -->

- [Задание](#задание)
- [Описание работы](#описание-работы)
  - [Общая информация](#общая-информация)
  - [Настройка машины server](#настройка-машины-server)
  - [Настройка машины client](#настройка-машины-client)
- [Проверка работы](#проверка-работы)

### Задание

Vagrant должен поднимать 2 виртуалки: сервер и клиент. На сервере должна быть расшарена директория. На клиенте она должна автоматически монтироваться при старте (fstab или autofs).

В шаре должна быть папка upload с правами на запись.

Требования для NFS: NFSv3 по UDP, включенный firewall.

### Описание работы

#### Общая информация

Для создания расшаренной директории используется NFS.

При выполнении команды `vagrant up` поднимаются две виртуальные машины: server и client ([Vagrantfile](Vagrantfile)), которые конфигурируются при помощи Ansible.

Для каждой машины написан свой стартовый плейбук. Все плейбуки находятся в каталоге [playbooks](provisioning/playbooks). 

#### Настройка машины server

[Ссылка на стартовый плейбук](provisioning/playbooks/nfs-server.yml)

1. Включается и конфигурируется файрвол: добавляются нужные для работы сервисы (nfs3, mountd, rpc-bind), после чего он перезапускается. Сервис файрвола nfs не используется, так как в нём, в отличие от nfs3, не открыт порт для протокола UDP.
2. Проверяется, установлен ли пакет nfs-utils, и устанавливается в случае отсутствия.
3. Запускаются и добавляются в автозагрузку службы rpcbind и nfs-server.
4. Создаётся директория **/var/nfs_share** с подкаталогом **upload**, им назначаются полные права доступа (777).
5. В файл /etc/expots вносятся следующие записи:

    ```
    /var/nfs_share 10.10.10.20(ro,sync,root_squash,no_all_squash)
    /var/nfs_share/upload 10.10.10.20(rw,sync,root_squash,no_all_squash)
    ```

    Таким образом, каталог **/var/nfs_share** расшаривается с правами только на чтение, а подкаталог **upload** — на чтение и запись.

6. Таблица экспорта перечитывается при помощи команды `expotrfs -r`.

#### Настройка машины client

[Ссылка на стартовый плейбук](provisioning/playbooks/nfs-client.yml)

1. Проверяется, установлен ли пакет nfs-utils, и устанавливается в случае отсутствия.
2. Запускается и добавляется в автозагрузку служба rpcbind.
3. Создаётся директория **/mnt/nfs**, которая будет точкой монтирования для файловой системы NFS.
4. К **/mnt/nfs** монтируется каталог **/vat/nfs_share**, расположенный на NFS-сервере. При этом указывается версия NFS 3 и протокол UDP. Монтирование каталога прописывается в **/etc/fstab**.
5. К директории **/mnt/nfs/upload**, подключенной на предыдущем шаге, монтируется каталог **/vat/nfs_share/upload**, расположенный на NFS-сервере. Аналогично предыдущему шагу указывается версия NFS 3 и протокол UDP, монтирование каталога также прописывается в **/etc/fstab**.

И монтирование файловых систем NFS, и редактирование файла **fstab** осуществляется при помощи одного ansible-модуля — mount.

Для файловых систем NFS в **fstab** указана опция `_netdev`, которая используется для предотвращения попытки системы смонтировать эти файловые системы до тех пор, пока в системе не будет включена сеть. Также заданы опции `noauto` и `x-systemd.automount` — таким образом, после перезагрузки системы расшаренные директории будут подключены только при непосредственном обращении к ним.

Кроме того, в **fstab** явно указано использование третьей версии NFS и протокола UDP: `vers=3,proto=udp`.

### Проверка работы

Чтобы создать и настроить виртуальные машины, достаточно выполнить команду `vagrant up`.

1. Зайдём на сервер NFS и убедимся, что файрвол включён:

    ```console
    [root@nfs-server ~]# firewall-cmd --state
    running
    [root@nfs-server ~]# firewall-cmd --list-services 
    dhcpv6-client mountd nfs3 rpc-bind ssh
    ```

2. Проверим таблицу экспортирования файловых систем NFS:

    ```console
    [root@nfs-server ~]# exportfs -s
    /var/nfs_share  10.10.10.20(sync,wdelay,hide,no_subtree_check,sec=sys,ro,secure,root_squash,no_all_squash)
    /var/nfs_share/upload  10.10.10.20(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
    ```

3. Добавим в каталог /vat/nfs_share какой-нибудь файл:

    ```console
    [root@nfs-server ~]# echo 'Some text' > /var/nfs_share/test.txt
    [root@nfs-server ~]# ls -l /var/nfs_share/
    -rw-r--r--. 1 root root 10 Jul 25 21:24 test.txt
    drwxrwxrwx. 2 root root 23 Jul 25 21:13 upload
    [root@nfs-server ~]# cat /var/nfs_share/test.txt
    Some text
    ```

4. Зайдём на машину-клиент. Убедимся, что расшаренные директории примонтированы:

    ```console
    [root@nfs-client ~]# df -Th -x tmpfs -x devtmpfs
    Filesystem                        Type  Size  Used Avail Use% Mounted on
    /dev/sda1                         xfs    40G  3.0G   38G   8% /
    10.10.10.10:/var/nfs_share        nfs    40G  3.0G   38G   8% /mnt/nfs
    10.10.10.10:/var/nfs_share/upload nfs    40G  3.0G   38G   8% /mnt/nfs/upload
    ```

    ```console
    [root@nfs-client ~]# mount | grep nfs
    sunrpc on /var/lib/nfs/rpc_pipefs type rpc_pipefs (rw,relatime)
    10.10.10.10:/var/nfs_share on /mnt/nfs type nfs (rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,proto=udp,timeo=11,retrans=3,sec=sys,mountaddr=10.10.10.10,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.10.10.10,_netdev)
    10.10.10.10:/var/nfs_share/upload on /mnt/nfs/upload type nfs (rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,proto=udp,timeo=11,retrans=3,sec=sys,mountaddr=10.10.10.10,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=10.10.10.10,_netdev)
    ```

5. Проверим содержимое каталога **/mnt/nfs**:

    ```console
    [root@nfs-client ~]# ls -l /mnt/nfs/
    total 4
    -rw-r--r--. 1 root root 10 Jul 25 21:24 test.txt
    drwxrwxrwx. 2 root root  6 Jul 25 21:13 upload
    [root@nfs-client ~]# cat /mnt/nfs/test.txt 
    Some text
    ```

    Мы не можем удалить из этого каталога что-либо, как и создать новые файлы, так как файловая система примонтирована в режиме только для чтения:

    ```console
    [root@nfs-client ~]# rm -f /mnt/nfs/test.txt 
    rm: cannot remove ‘/mnt/nfs/test.txt’: Read-only file system
    [root@nfs-client ~]# touch /mnt/nfs/newfile
    touch: cannot touch ‘/mnt/nfs/newfile’: Read-only file system
    ```

    Директорию upload удалить также нельзя:

    ```console
    [root@nfs-client ~]# rm -rf /mnt/nfs/upload/
    rm: cannot remove ‘/mnt/nfs/upload/’: Device or resource busy
    ```

    Однако мы можем добавлять в неё новые файлы:

    ```console
    [root@nfs-client ~]# echo 'I can write in shared folder' > /mnt/nfs/upload/hello.txt
    [root@nfs-client ~]# ls -l /mnt/nfs/upload/
    total 4
    -rw-r--r--. 1 nfsnobody nfsnobody 29 Jul 25 21:38 hello.txt
    [root@nfs-client ~]# cat /mnt/nfs/upload/hello.txt
    I can write in shared folder
    ```

    Проверим содержимое каталога **/var/nfs_share/upload** на сервере:

    ```console
    [root@nfs-server ~]# ls -l /var/nfs_share/upload/
    total 0
    -rw-r--r--. 1 nfsnobody nfsnobody 29 Jul 25 21:38 hello.txt
    [root@nfs-server ~]# cat /var/nfs_share/upload/hello.txt 
    I can write in shared folder
    ```

6. Убедимся, что используется именно третья версия NFS:

    ```console
    [root@nfs-client ~]# nfsstat -l
    nfs v3 client        total:       38 
    ------------- ------------- --------
    nfs v3 client      getattr:       16 
    nfs v3 client       lookup:        4 
    nfs v3 client       access:        5 
    nfs v3 client        write:        1 
    nfs v3 client       create:        2 
    nfs v3 client       remove:        1 
    nfs v3 client  readdirplus:        3 
    nfs v3 client       fsinfo:        4 
    nfs v3 client     pathconf:        2  
    ```

7. Проверим содержимое файла **/etc/fstab** на клиенте:

    ```console
    [root@nfs-client ~]# cat /etc/fstab | egrep -v '^#|^$'
    UUID=1c419d6c-5064-4a2b-953c-05b2c67edb15 /                       xfs     defaults        0 0
    /swapfile none swap defaults 0 0
    10.10.10.10:/var/nfs_share /mnt/nfs nfs vers=3,proto=udp,hard,intr,_netdev,noauto,x-systemd.automount 0 0
    10.10.10.10:/var/nfs_share/upload /mnt/nfs/upload nfs vers=3,proto=udp,hard,intr,_netdev,noauto,x-systemd.automount 0 0
    ```

8. Перезагрузим клиента, снова зайдём на него и проверим каталог **/mnt/nfs/upload**, убедившись, что он монтируется при обращении к нему:

    ```console
    [root@nfs-client ~]# ls -l /mnt/nfs/upload/
    total 4
    -rw-r--r--. 1 nfsnobody nfsnobody 29 Jul 25 21:38 hello.txt
    ```

<br/>

[Вернуться к списку всех ДЗ](../README.md)
