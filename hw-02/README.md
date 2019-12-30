## Домашнее задание № 2 — «Дисковая подсистема»

### Оглавление

- [Добавление дисков в Vagrantfile](#добавление-дисков-в-vagrantfile)
- [Сборка RAID-массива](#сборка-raid-массива)
- [Поломка и восстановление RAID-массива](#поломка-и-восстановление-raid-массива)
- [Создание структуры GPT и пяти разделов](#создание-структуры-gpt-и-пяти-разделов)
- [Дополнительное задание](#дополнительное-задание)

### Добавление дисков в Vagrantfile

[Vagrantfile](Vagrantfile) с добавленными дисками находится в каталоге.

За добавление диска отвечает блок:
```ruby
:sata5 => {
    :dfile => home + '/VirtualBox VMs/disks/sata5.vdi', # Путь, по которому будет создан файл диска
    :size => 250,                                       # Размер диска в мегабайтах
    :port => 5                                          # Номер порта, на который будет зацеплен диск
},
```
Переменная `home` задаётся ранее следующим образом:
```ruby
home = ENV['HOME']
```
В приложенном [Vagrantfile](Vagrantfile) создаётся шесть дополнительных дисков.

Чтобы создать виртуальную машину при помощи указанного Vagrantfile, необходимо в папке с ним выполнить команду `vagrant up`. Далее заходим на эту машину при помощи команды `vagrant ssh`.

### Сборка RAID-массива

В данном домашнем задании создаётся RAID 10.

Выведем список всех дисков:
```console
[root@otuslinux vagrant]# lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   40G  0 disk 
`-sda1   8:1    0   40G  0 part /
sdb      8:16   0  250M  0 disk 
sdc      8:32   0  250M  0 disk 
sdd      8:48   0  250M  0 disk 
sde      8:64   0  250M  0 disk 
sdf      8:80   0  250M  0 disk 
sdg      8:96   0  250M  0 disk
```
Создадим массив:
```console
[root@otuslinux vagrant]# mdadm --create --verbose /dev/md0 --level=10 --raid-devices=6 /dev/sd{b,c,d,e,f,g}
mdadm: layout defaults to n2
mdadm: layout defaults to n2
mdadm: chunk size defaults to 512K
mdadm: size set to 253952K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
```
Проверим:
```console
[root@otuslinux vagrant]# cat /proc/mdstat
Personalities : [raid10] 
md0 : active raid10 sdg[5] sdf[4] sde[3] sdd[2] sdc[1] sdb[0]
      761856 blocks super 1.2 512K chunks 2 near-copies [6/6] [UUUUUU]
```
```console
[root@otuslinux vagrant]# mdadm --detail /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Fri Dec 13 21:46:16 2019
        Raid Level : raid10
        Array Size : 761856 (744.00 MiB 780.14 MB)
     Used Dev Size : 253952 (248.00 MiB 260.05 MB)
      Raid Devices : 6
     Total Devices : 6
       Persistence : Superblock is persistent

       Update Time : Fri Dec 13 21:46:27 2019
             State : clean 
    Active Devices : 6
   Working Devices : 6
    Failed Devices : 0
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : 56112ca3:472fe26e:656fc1db:00053a7c
            Events : 17

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
       2       8       48        2      active sync set-A   /dev/sdd
       3       8       64        3      active sync set-B   /dev/sde
       4       8       80        4      active sync set-A   /dev/sdf
       5       8       96        5      active sync set-B   /dev/sdg
```
```console
[root@otuslinux vagrant]# lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINT
sda      8:0    0   40G  0 disk   
`-sda1   8:1    0   40G  0 part   /
sdb      8:16   0  250M  0 disk   
`-md0    9:0    0  744M  0 raid10 
sdc      8:32   0  250M  0 disk   
`-md0    9:0    0  744M  0 raid10 
sdd      8:48   0  250M  0 disk   
`-md0    9:0    0  744M  0 raid10 
sde      8:64   0  250M  0 disk   
`-md0    9:0    0  744M  0 raid10 
sdf      8:80   0  250M  0 disk   
`-md0    9:0    0  744M  0 raid10 
sdg      8:96   0  250M  0 disk   
`-md0    9:0    0  744M  0 raid10
```
Число в параметре `Layout` в выводе команды `mdadm --detail /dev/md0` указывает количество копий для каждого блока данных. В данном случае это 2 (значение по умолчанию). Таким образом, наш массив представляет собой RAID 0, состоящий из трёх RAID 1, каждый из которых, в свою очередь, состоит из двух дисков. 

### Поломка и восстановление RAID-массива

Пометим один из дисков как сбойный и проверим результат:
```console
[root@otuslinux vagrant]# mdadm /dev/md0 --fail /dev/sde
mdadm: set /dev/sde faulty in /dev/md0
[root@otuslinux vagrant]# cat /proc/mdstat
Personalities : [raid10] 
md0 : active raid10 sdg[5] sdf[4] sde[3](F) sdd[2] sdc[1] sdb[0]
      761856 blocks super 1.2 512K chunks 2 near-copies [6/5] [UUU_UU]
```
Удалим сбойный диск и добавим новый:
```console
[root@otuslinux vagrant]# mdadm /dev/md0 --remove /dev/sde
mdadm: hot removed /dev/sde from /dev/md0
[root@otuslinux vagrant]# mdadm /dev/md0 --add /dev/sde
mdadm: added /dev/sde
```
Посмотрим процесс ребилда:
```console
[root@otuslinux vagrant]# cat /proc/mdstat
Personalities : [raid10] 
md0 : active raid10 sde[6] sdg[5] sdf[4] sdd[2] sdc[1] sdb[0]
      761856 blocks super 1.2 512K chunks 2 near-copies [6/5] [UUU_UU]
      [==============>......]  recovery = 73.0% (186112/253952) finish=0.0min speed=46528K/sec
```
И результат:
```console
[root@otuslinux vagrant]# cat /proc/mdstat
Personalities : [raid10] 
md0 : active raid10 sde[6] sdg[5] sdf[4] sdd[2] sdc[1] sdb[0]
      761856 blocks super 1.2 512K chunks 2 near-copies [6/6] [UUUUUU]
```

### Создание структуры GPT и пяти разделов

Создаем раздел GPT на RAID:
```console
[root@otuslinux vagrant]# parted -s /dev/md0 mklabel gpt
```
Создаем партиции:
```console
[root@otuslinux vagrant]# parted /dev/md0 mkpart primary ext4 0% 20%
[root@otuslinux vagrant]# parted /dev/md0 mkpart primary ext4 20% 40%
[root@otuslinux vagrant]# parted /dev/md0 mkpart primary ext4 40% 60%
[root@otuslinux vagrant]# parted /dev/md0 mkpart primary ext4 60% 80%
[root@otuslinux vagrant]# parted /dev/md0 mkpart primary ext4 80% 100%
```
Создаём на этих партициях ФС и монтируем их по каталогам:
```console
[root@otuslinux vagrant]# for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
[root@otuslinux vagrant]# mkdir -p /raid/part{1,2,3,4,5}
[root@otuslinux vagrant]# for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done
```
Проверяем:
```console
[root@otuslinux vagrant]# df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        40G  2.9G   38G   8% /
devtmpfs        488M     0  488M   0% /dev
tmpfs           496M     0  496M   0% /dev/shm
tmpfs           496M  6.7M  489M   2% /run
tmpfs           496M     0  496M   0% /sys/fs/cgroup
tmpfs           100M     0  100M   0% /run/user/1000
/dev/md0p1      139M  1.6M  127M   2% /raid/part1
/dev/md0p2      140M  1.6M  128M   2% /raid/part2
/dev/md0p3      142M  1.6M  130M   2% /raid/part3
/dev/md0p4      140M  1.6M  128M   2% /raid/part4
/dev/md0p5      139M  1.6M  127M   2% /raid/part5
```

### Дополнительное задание

Задание со звёздочкой: Vagrantfile, который сразу собирает систему с подключенным рейдом.

Для этого добавим в Vagrantfile к box.vm.provision следующие строки:

`mdadm --zero-superblock --force /dev/sd{b,c,d,e,f,g}` — обнуляем суперблоки;

`mdadm --create --verbose /dev/md0 --level=10 --raid-devices=6 /dev/sd{b,c,d,e,f,g}` — создаём массив;

`mkfs.ext4 /dev/md0` — создаём в массиве файловую систему;

`mkdir -p /mnt/md0` — создаём точку монтирования;

`mount /dev/md0 /mnt/md0` — монтируем файловую систему.

Таким образом, провижининг в Vagrantfile приобретёт следующий вид:
```ruby
box.vm.provision "shell", inline: <<-SHELL
    mkdir -p ~root/.ssh
    cp ~vagrant/.ssh/auth* ~root/.ssh
    yum install -y mdadm smartmontools hdparm gdisk
    mdadm --zero-superblock --force /dev/sd{b,c,d,e,f,g}
    mdadm --create --verbose /dev/md0 --level=10 --raid-devices=6 /dev/sd{b,c,d,e,f,g}
    mkfs.ext4 /dev/md0
    mkdir -p /mnt/md0
    mount /dev/md0 /mnt/md0
SHELL
```
Выполним команды `vagrant up` и `vagrant ssh` и проверим, что массив создан и примонтирован:
```console
[vagrant@otuslinux ~]$ lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINT
sda      8:0    0   40G  0 disk   
`-sda1   8:1    0   40G  0 part   /
sdb      8:16   0  250M  0 disk   
`-md0    9:0    0  744M  0 raid10 /mnt/md0
sdc      8:32   0  250M  0 disk   
`-md0    9:0    0  744M  0 raid10 /mnt/md0
sdd      8:48   0  250M  0 disk   
`-md0    9:0    0  744M  0 raid10 /mnt/md0
sde      8:64   0  250M  0 disk   
`-md0    9:0    0  744M  0 raid10 /mnt/md0
sdf      8:80   0  250M  0 disk   
`-md0    9:0    0  744M  0 raid10 /mnt/md0
sdg      8:96   0  250M  0 disk   
`-md0    9:0    0  744M  0 raid10 /mnt/md0
```
```console
[vagrant@otuslinux ~]$ cat /proc/mdstat 
Personalities : [raid10] 
md0 : active raid10 sdg[5] sdf[4] sde[3] sdd[2] sdc[1] sdb[0]
      761856 blocks super 1.2 512K chunks 2 near-copies [6/6] [UUUUUU]
```
```console
[vagrant@otuslinux ~]$ df -h
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        40G  2.9G   38G   8% /
devtmpfs        488M     0  488M   0% /dev
tmpfs           496M     0  496M   0% /dev/shm
tmpfs           496M  6.7M  489M   2% /run
tmpfs           496M     0  496M   0% /sys/fs/cgroup
/dev/md0        717M  1.5M  663M   1% /mnt/md0
tmpfs           100M     0  100M   0% /run/user/1000
```

<br/>

[Вернуться к списку всех ДЗ](../README.md)