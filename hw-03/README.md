 ## Домашнее задание № 3 — «Файловые системы и LVM»

### Оглавление

- [Уменьшение тома под **/** до 8 Гб](#уменьшение-тома-под-до-8-гб)
- [Выделение тома под **/var**, преобразование в mirror](#выделение-тома-под-var-преобразование-в-mirror)
- [Выделение тома под **/home**](#выделение-тома-под-home)
- [Создание тома для снэпшотов **/home**](#создание-тома-для-снэпшотов-home)


Для начала необходимо развернуть виртуальную машину из [Vagrantfile](Vagrantfile) при помощи команды `vagrant up`. Далее заходим в неё командой `vagrant ssh` и логинимся как суперпользователь (так как все работы требуют повышенных прав).

### Уменьшение тома под **/** до 8 Гб

Подготовим временный том для **/** раздела, создадим на нем файловую систему и смонтируем его, чтобы перенести туда данные:

```console
[root@lvm vagrant]# pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.
[root@lvm vagrant]# vgcreate vg_root /dev/sdb
  Volume group "vg_root" successfully created
[root@lvm vagrant]# lvcreate -n lv_root -l+100%FREE /dev/vg_root
  Logical volume "lv_root" created.
[root@lvm vagrant]# mkfs.xfs /dev/vg_root/lv_root
meta-data=/dev/vg_root/lv_root   isize=512    agcount=4, agsize=655104 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=2620416, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
[root@lvm vagrant]# mount /dev/vg_root/lv_root /mnt
[root@lvm vagrant]# df -Th | grep mnt
/dev/mapper/vg_root-lv_root     xfs        10G   33M   10G   1% /mnt
```

Скопируем все данные с **/** раздела в **/mnt**:

```console
[root@lvm vagrant]# xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
...
xfsdump: Dump Status: SUCCESS
xfsrestore: restore complete: 56 seconds elapsed
xfsrestore: Restore Status: SUCCESS
```

Проверим:

```console
[root@lvm vagrant]# ll /mnt
total 12
lrwxrwxrwx.  1 root    root       7 Dec 17 16:38 bin -> usr/bin
drwxr-xr-x.  2 root    root       6 May 12  2018 boot
drwxr-xr-x.  2 root    root       6 May 12  2018 dev
drwxr-xr-x. 79 root    root    8192 Dec 17 16:26 etc
drwxr-xr-x.  3 root    root      21 May 12  2018 home
lrwxrwxrwx.  1 root    root       7 Dec 17 16:38 lib -> usr/lib
lrwxrwxrwx.  1 root    root       9 Dec 17 16:38 lib64 -> usr/lib64
drwxr-xr-x.  2 root    root       6 Apr 11  2018 media
drwxr-xr-x.  2 root    root       6 Apr 11  2018 mnt
drwxr-xr-x.  2 root    root       6 Apr 11  2018 opt
drwxr-xr-x.  2 root    root       6 May 12  2018 proc
dr-xr-x---.  3 root    root     149 Dec 17 16:26 root
drwxr-xr-x.  2 root    root       6 May 12  2018 run
lrwxrwxrwx.  1 root    root       8 Dec 17 16:38 sbin -> usr/sbin
drwxr-xr-x.  2 root    root       6 Apr 11  2018 srv
drwxr-xr-x.  2 root    root       6 May 12  2018 sys
drwxrwxrwt.  8 root    root     256 Dec 17 16:36 tmp
drwxr-xr-x. 13 root    root     155 May 12  2018 usr
drwxrwxr-x.  2 vagrant vagrant   42 Dec 15 19:51 vagrant
drwxr-xr-x. 18 root    root     254 Dec 17 16:25 var
```

Сымитируем текущий **root**, сделаем в него `chroot` и обновим **grub**:

```console
[root@lvm vagrant]# for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
[root@lvm vagrant]# chroot /mnt/
[root@lvm /]# grub2-mkconfig -o /boot/grub2/grub.cfg 
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-862.2.3.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-862.2.3.el7.x86_64.img
done
[root@lvm /]# cd /boot; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
...
*** Creating image file ***
*** Creating image file done ***
*** Creating initramfs image file '/boot/initramfs-3.10.0-862.2.3.el7.x86_64.img' done ***
```

Для того, чтобы при загрузке был смонтирован нужный **root**, в файле **/boot/grub2/grub.cfg** заменим `rd.lvm.lv=VolGroup00/LogVol00` на `rd.lvm.lv=vg_root/lv_root`.

Перезагружаем виртуальную машину командой `vagrant reload`, выполненной на хосте. Убедиться в том, что загрузка прошла с новым корневым каталогом, можно, посмотрев вывод `lsblk`:

```console
[vagrant@lvm ~]$ lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part 
  ├─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol00 253:2    0 37.5G  0 lvm  
sdb                       8:16   0   10G  0 disk 
└─vg_root-lv_root       253:0    0   10G  0 lvm  /
sdc                       8:32   0    2G  0 disk 
sdd                       8:48   0    1G  0 disk 
sde                       8:64   0    1G  0 disk
```

Удаляем старый Logical Volume размером в 40 Гб и создаем новый на 8 Гб:

```console
[root@lvm vagrant]# lvremove /dev/VolGroup00/LogVol00
Do you really want to remove active logical volume VolGroup00/LogVol00? [y/n]: y
  Logical volume "LogVol00" successfully removed
[root@lvm vagrant]# lvcreate -n VolGroup00/LogVol00 -L 8G /dev/VolGroup00
WARNING: xfs signature detected on /dev/VolGroup00/LogVol00 at offset 0. Wipe it? [y/n]: y
  Wiping xfs signature on /dev/VolGroup00/LogVol00.
  Logical volume "LogVol00" created.
```

Повторяем операции по переносу **/**:

```console
[root@lvm vagrant]# mkfs.xfs /dev/VolGroup00/LogVol00
meta-data=/dev/VolGroup00/LogVol00 isize=512    agcount=4, agsize=524288 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=2097152, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
[root@lvm vagrant]# mount /dev/VolGroup00/LogVol00 /mnt
[root@lvm vagrant]# xfsdump -J - /dev/vg_root/lv_root | xfsrestore -J - /mnt
...
xfsdump: dump complete: 58 seconds elapsed
xfsdump: Dump Status: SUCCESS
xfsrestore: restore complete: 58 seconds elapsed
xfsrestore: Restore Status: SUCCESS
```

Переконфигурируем **grub** (за исключением правки **/etc/grub2/grub.cfg**):

```console
[root@lvm vagrant]# for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
[root@lvm vagrant]# chroot /mnt/
[root@lvm /]# grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-862.2.3.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-862.2.3.el7.x86_64.img
done
[root@lvm /]# cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
Executing: /sbin/dracut -v initramfs-3.10.0-862.2.3.el7.x86_64.img 3.10.0-862.2.3.el7.x86_64 --force
...
*** Creating image file ***
*** Creating image file done ***
*** Creating initramfs image file '/boot/initramfs-3.10.0-862.2.3.el7.x86_64.img' done ***
```

Не перезагружаемся и не выходим из под `chroot`, чтобы сразу сделать следующее задание — перенос **/var**.

### Выделение тома под **/var**, преобразование в mirror

На свободных дисках создаем зеркало:

```console
[root@lvm boot]# pvcreate /dev/sdc /dev/sdd
  Physical volume "/dev/sdc" successfully created.
  Physical volume "/dev/sdd" successfully created.
[root@lvm boot]# vgcreate vg_var /dev/sd{c,d}
  Volume group "vg_var" successfully created
[root@lvm boot]# lvcreate -L 950M -m1 -n lv_var vg_var
  Rounding up size to full physical extent 952.00 MiB
  Logical volume "lv_var" created.
```

Создаем на нем файловую систему и перемещаем туда **/var**:

```console
[root@lvm boot]# mkfs.ext4 /dev/vg_var/lv_var 
mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=4096 (log=2)
Fragment size=4096 (log=2)
Stride=0 blocks, Stripe width=0 blocks
60928 inodes, 243712 blocks
12185 blocks (5.00%) reserved for the super user
First data block=0
Maximum filesystem blocks=249561088
8 block groups
32768 blocks per group, 32768 fragments per group
7616 inodes per group
Superblock backups stored on blocks: 
        32768, 98304, 163840, 229376

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

[root@lvm boot]# mount /dev/vg_var/lv_var /mnt
[root@lvm boot]# cp -aR /var/* /mnt
```

На всякий случай сохраняем содержимое старого **var**:

```console
[root@lvm boot]# mkdir /tmp/oldvar && mv /var/* /tmp/oldvar
```

Монтируем новый **var** в каталог **/var***:

```console
[root@lvm boot]# umount /mnt
[root@lvm boot]# mount /dev/vg_var/lv_var /var
```

Правим **fstab** для автоматического монтирования **/var**:

```console
[root@lvm boot]# echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab
```

Командой `vagrant reload`, выполненной на хосте, перезагружаемся в новый — уменьшенный — **root** и удаляем временную Volume Group:

```console
[root@lvm vagrant]# lvremove /dev/vg_root/lv_root 
Do you really want to remove active logical volume vg_root/lv_root? [y/n]: y
  Logical volume "lv_root" successfully removed
[root@lvm vagrant]# vgremove /dev/vg_root
  Volume group "vg_root" successfully removed
[root@lvm vagrant]# pvremove /dev/sdb
  Labels on physical volume "/dev/sdb" successfully wiped.
```

Проверяем, что раздел под **/** уменьшился, а **/var** находится в новом разделе с зеркалом:

```console
[root@lvm vagrant]# lsblk
NAME                     MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                        8:0    0   40G  0 disk 
├─sda1                     8:1    0    1M  0 part 
├─sda2                     8:2    0    1G  0 part /boot
└─sda3                     8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00  253:0    0    8G  0 lvm  /
  └─VolGroup00-LogVol01  253:1    0  1.5G  0 lvm  [SWAP]
sdb                        8:16   0   10G  0 disk 
sdc                        8:32   0    2G  0 disk 
├─vg_var-lv_var_rmeta_0  253:3    0    4M  0 lvm  
│ └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0 253:4    0  952M  0 lvm  
  └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
sdd                        8:48   0    1G  0 disk 
├─vg_var-lv_var_rmeta_1  253:5    0    4M  0 lvm  
│ └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1 253:6    0  952M  0 lvm  
  └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
sde                        8:64   0    1G  0 disk 
```

### Выделение тома под **/home**

Выделяем том под **/home** и переносим в него содержимое каталога **/home/**:

```console
[root@lvm vagrant]# lvcreate -n LogVol_Home -L 2G /dev/VolGroup00
  Logical volume "LogVol_Home" created.
[root@lvm vagrant]# mkfs.xfs /dev/VolGroup00/LogVol_Home 
meta-data=/dev/VolGroup00/LogVol_Home isize=512    agcount=4, agsize=131072 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=524288, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
[root@lvm vagrant]# mount /dev/VolGroup00/LogVol_Home  /mnt/
[root@lvm vagrant]# cp -aR /home/* /mnt/
[root@lvm vagrant]# rm -rf /home/*
[root@lvm vagrant]# umount /mnt/
[root@lvm vagrant]# mount /dev/VolGroup00/LogVol_Home /home/
[root@lvm vagrant]# echo "`blkid | grep Home | awk '{print $2}'` /home xfs defaults 0 0" >> /etc/fstab
```

Проверяем:

```console
[root@lvm vagrant]# lsblk
NAME                       MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                          8:0    0   40G  0 disk 
├─sda1                       8:1    0    1M  0 part 
├─sda2                       8:2    0    1G  0 part /boot
└─sda3                       8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00    253:0    0    8G  0 lvm  /
  ├─VolGroup00-LogVol01    253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol_Home 253:2    0    2G  0 lvm  /home
sdb                          8:16   0   10G  0 disk 
sdc                          8:32   0    2G  0 disk 
├─vg_var-lv_var_rmeta_0    253:3    0    4M  0 lvm  
│ └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0   253:4    0  952M  0 lvm  
  └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
sdd                          8:48   0    1G  0 disk 
├─vg_var-lv_var_rmeta_1    253:5    0    4M  0 lvm  
│ └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1   253:6    0  952M  0 lvm  
  └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
sde                          8:64   0    1G  0 disk 
[root@lvm vagrant]# df -h
Filesystem                          Size  Used Avail Use% Mounted on
/dev/mapper/VolGroup00-LogVol00     8.0G  756M  7.3G  10% /
devtmpfs                            110M     0  110M   0% /dev
tmpfs                               118M     0  118M   0% /dev/shm
tmpfs                               118M  4.5M  114M   4% /run
tmpfs                               118M     0  118M   0% /sys/fs/cgroup
/dev/sda2                          1014M   61M  954M   6% /boot
/dev/mapper/vg_var-lv_var           922M  129M  729M  16% /var
/dev/mapper/VolGroup00-LogVol_Home  2.0G   33M  2.0G   2% /home
```

### Создание тома для снэпшотов **/home**

Сгенерируем файлы в **/home/**:

```console
[root@lvm vagrant]# touch /home/file{1..20}
[root@lvm vagrant]# ll /home/
total 0
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file1
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file10
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file11
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file12
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file13
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file14
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file15
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file16
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file17
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file18
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file19
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file2
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file20
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file3
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file4
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file5
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file6
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file7
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file8
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file9
drwx------. 3 vagrant vagrant 95 Dec 17 23:39 vagrant
```
Создаём том для снэпшотов:

```console
[root@lvm vagrant]# lvcreate -L 100M -s -n home_snap /dev/VolGroup00/LogVol_Home
  Rounding up size to full physical extent 128.00 MiB
  Logical volume "home_snap" created.
```

Удалим часть файлов:

```console
[root@lvm vagrant]# rm -f /home/file{11..20}
[root@lvm vagrant]# ll /home/
total 0
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file1
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file10
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file2
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file3
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file4
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file5
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file6
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file7
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file8
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file9
drwx------. 3 vagrant vagrant 95 Dec 17 23:39 vagrant
```

```console
[root@lvm vagrant]# umount /home
[root@lvm vagrant]# lvconvert --merge /dev/VolGroup00/home_snap 
  Merging of volume VolGroup00/home_snap started.
  VolGroup00/LogVol_Home: Merged: 100.00%
[root@lvm vagrant]# mount /home
```

Восстановим эти файлы со снапшота:

```console
[root@lvm vagrant]# ll /home/
total 0
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file1
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file10
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file11
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file12
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file13
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file14
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file15
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file16
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file17
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file18
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file19
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file2
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file20
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file3
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file4
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file5
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file6
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file7
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file8
-rw-r--r--. 1 root    root     0 Dec 18 22:15 file9
drwx------. 3 vagrant vagrant 95 Dec 17 23:39 vagrant
```

<br/>

[Вернуться к списку всех ДЗ](../README.md)