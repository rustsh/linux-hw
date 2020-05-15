## Домашнее задание к занятию № 25 — «Сетевые пакеты. VLAN'ы. LACP»  <!-- omit in toc -->

### Оглавление  <!-- omit in toc -->

- [Задание](#Задание)
- [Описание работы](#Описание-работы)
  - [Предварительная настройка](#Предварительная-настройка)
  - [VLAN](#vlan)
  - [Агрегирование каналов](#Агрегирование-каналов)
- [Проверка работы](#Проверка-работы)
  - [Проверка работы VLAN](#Проверка-работы-vlan)
  - [Проверка работы агрегированных каналов](#Проверка-работы-агрегированных-каналов)

### Задание

В сети Office1 в тестовой подсети появляются серверы с доп. интерфесами и адресами во внутренней сети testLAN:

- testClient1 — 10.10.10.254;
- testClient2 — 10.10.10.254;
- testServer1 — 10.10.10.1;
- testServer2 — 10.10.10.1.

Развести VLAN'ами:

```
testClient1 <-> testServer1
testClient2 <-> testServer2
```

Между centralRouter и inetRouter "пробросить" 2 линка (общая внутренняя сеть) и объединить их в bond/team. Проверить работу c отключением интерфейсов.

### Описание работы

Для создания хостов с дополнительными интерфейсами используется Vagrant ([Vagrantfile](Vagrantfile)). Конфигурирование производится посредством Ansible.

[Плейбук для конфигурирования](provisioning/start.yml):

```yml
---
- name: Initial network settings
  hosts: all
  roles:
    - init_net

- name: Config vlan1
  hosts: testServer1, testClient1
  vars:
    vlan_number: 1
  roles:
    - vlan

- name: Config vlan2
  hosts: testServer2, testClient2
  vars:
    vlan_number: 2
  roles:
    - vlan

- name: Config vlan on router
  hosts: centralRouter
  roles:
    - vlan

- name: Config teaming
  hosts: inetRouter, centralRouter
  roles:
    - team
```

#### Предварительная настройка

Для предварительной настройки хостов создана роль [init_net](provisioning/roles/init_net).

При запуске роли:

1. Устанавливается tcpdump.
2. Выключается служба NetworkManager.
3. В каталог **/etc/sysconfig/network** копируется файл [network](provisioning/roles/init_net/templates/network.j2), в котором:
   - явно указано использование сети: `NETWORKING=yes`;
   - указано имя хоста (специфично для каждого сервера): `HOSTNAME=inetRouter`;
   - отключаются маршруты ZEROCONF (маршруты для сети 169.254.0.0/16): `NOZEROCONF=yes`;
   - указан адрес шлюза:
     - `GATEWAY=192.168.255.1` для centralRouter;
     - `GATEWAY=10.10.10.10` для тестовых серверов и клиентов.

#### VLAN

Для конфигурирования VLAN создана роль [vlan](provisioning/roles/vlan).

##### Конфигурирование серверов и клиентов  <!-- omit in toc -->

При запуске роли в каталог **/etc/sysconfig/network-scripts** на хостах testServer1, testClient1, testServer2 и testClient2 добавляются файл конфигурирования физического порта **ifcfg-eth1** и файл конфигурирования VLAN **ifcfg-vlan**. К названию файла конфигурирования и параметру `DEVICE` внутри него добавляется номер VLAN, который задаётся в плейбуке. После создания файлов перезапускается сервис network.

Содержимое файла **ifcfg-eth1**:

```ini
DEVICE=eth1
ONBOOT=yes
BOOTPROTO=none
NM_CONTROLLED=no
```

Пример файла **ifcfg-vlan1**:

```ini
VLAN=yes
VLAN_NAME_TYPE=VLAN_PLUS_VID_NO_PAD
DEVICE=vlan1
PHYSDEV=eth1
BOOTPROTO=none
ONBOOT=yes
TYPE=Ethernet
IPADDR=10.10.10.254
PREFIX=24
NM_CONTROLLED=no
```

##### Конфигурирование роутера  <!-- omit in toc -->

При запуске роли в каталог **/etc/sysconfig/network-scripts** на centralRouter добавляются файл конфигурирования физического порта **ifcfg-eth3** и файлы конфигурирования VLAN **ifcfg-vlan1** и **ifcfg-vlan2**. Их содержимое аналогично содержимому файлов на других хостах. И vlan1, и vlan2 в качестве физического интерфейса используют eth3.

#### Агрегирование каналов

Для конфигурирования агрегированных каналов создана роль [team](provisioning/roles/team).

При запуске роли в каталог **/etc/sysconfig/network-scripts** на хостах inetRouter и centralRouter добавляются файлы конфигурирования физических портов **ifcfg-eth1** и **ifcfg-eth2**, а также файл для их объединения в teaming — **ifcfg-team0**. После создания файлов перезапускается сервис network.

Пример файла **ifcfg-eth1**:

```ini
DEVICE=eth1
DEVICETYPE=TeamPort
ONBOOT=yes
NM_CONTROLLED=no
TEAM_MASTER=team0
TEAM_PORT_CONFIG='{"prio": 100}'
```

Пример файла **ifcfg-team0**:

```ini
DEVICE=team0
DEVICETYPE=Team
ONBOOT=yes
BOOTPROTO=none
IPADDR=192.168.255.1
PREFIX=30
NM_CONTROLLED=no
TEAM_CONFIG='{"runner": {"name": "activebackup", "hwaddr_policy": "by_active"}, "link_watch": {"name": "ethtool"}}'
```

### Проверка работы

#### Проверка работы VLAN

1. Проверим, что VLAN созданы:

    ```console
    [vagrant@testServer2 ~]$ ip a
    1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
        link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
        inet 127.0.0.1/8 scope host lo
           valid_lft forever preferred_lft forever
        inet6 ::1/128 scope host 
           valid_lft forever preferred_lft forever
    2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
        link/ether 52:54:00:8a:fe:e6 brd ff:ff:ff:ff:ff:ff
        inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic eth0
           valid_lft 85846sec preferred_lft 85846sec
        inet6 fe80::5054:ff:fe8a:fee6/64 scope link 
           valid_lft forever preferred_lft forever
    3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
        link/ether 08:00:27:7e:d5:6e brd ff:ff:ff:ff:ff:ff
        inet6 fe80::a00:27ff:fe7e:d56e/64 scope link 
           valid_lft forever preferred_lft forever
    6: vlan2@eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
        link/ether 08:00:27:7e:d5:6e brd ff:ff:ff:ff:ff:ff
        inet 10.10.10.254/24 brd 10.10.10.255 scope global vlan2
           valid_lft forever preferred_lft forever
        inet6 fe80::a00:27ff:fe7e:d56e/64 scope link 
           valid_lft forever preferred_lft forever
    ```

2. Запустим tcpdump на обоих клиентах:

    ```console
    sudo tcpdump -nnt -i any icmp
    ```

    Выполним на одном из серверов (например, testServer2) ping до клиента:

    ```console
    [vagrant@testServer2 ~]$ ping 10.10.10.1
    ```

    Вывод tcpdump на testClient2:

    ```console
    [vagrant@testClient2 ~]$ sudo tcpdump -nnt -i any icmp
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on any, link-type LINUX_SLL (Linux cooked), capture size 262144 bytes
    ethertype IPv4, IP 10.10.10.254 > 10.10.10.1: ICMP echo request, id 10772, seq 89, length 64
    IP 10.10.10.254 > 10.10.10.1: ICMP echo request, id 10772, seq 89, length 64
    IP 10.10.10.1 > 10.10.10.254: ICMP echo reply, id 10772, seq 89, length 64
    ethertype IPv4, IP 10.10.10.1 > 10.10.10.254: ICMP echo reply, id 10772, seq 89, length 64
    ethertype IPv4, IP 10.10.10.254 > 10.10.10.1: ICMP echo request, id 10772, seq 90, length 64
    IP 10.10.10.254 > 10.10.10.1: ICMP echo request, id 10772, seq 90, length 64
    IP 10.10.10.1 > 10.10.10.254: ICMP echo reply, id 10772, seq 90, length 64
    ethertype IPv4, IP 10.10.10.1 > 10.10.10.254: ICMP echo reply, id 10772, seq 90, length 64
    ^C
    8 packets captured
    8 packets received by filter
    0 packets dropped by kernel
    ```

    Вывод tcpdump на testClient1 пустой:

    ```console
    [vagrant@testClient1 ~]$ sudo tcpdump -nnt -i any icmp
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on any, link-type LINUX_SLL (Linux cooked), capture size 262144 bytes
    ^C
    0 packets captured
    0 packets received by filter
    0 packets dropped by kernel
    ```

3. Проверим то же самое для testServer1:

    ```console
    [vagrant@testServer1 ~]$ ping 10.10.10.1
    ```

    testClient2:

    ```console
    [vagrant@testClient2 ~]$ sudo tcpdump -nnt -i any icmp
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on any, link-type LINUX_SLL (Linux cooked), capture size 262144 bytes
    ^C
    0 packets captured
    0 packets received by filter
    0 packets dropped by kernel
    ```

    testClient1:

    ```console
    [vagrant@testClient1 ~]$ sudo tcpdump -nnt -i any icmp
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on any, link-type LINUX_SLL (Linux cooked), capture size 262144 bytes
    ethertype IPv4, IP 10.10.10.254 > 10.10.10.1: ICMP echo request, id 12021, seq 30, length 64
    IP 10.10.10.254 > 10.10.10.1: ICMP echo request, id 12021, seq 30, length 64
    IP 10.10.10.1 > 10.10.10.254: ICMP echo reply, id 12021, seq 30, length 64
    ethertype IPv4, IP 10.10.10.1 > 10.10.10.254: ICMP echo reply, id 12021, seq 30, length 64
    ^C
    4 packets captured
    4 packets received by filter
    0 packets dropped by kernel
    ```

4. Выключим testClient1 (командой `vagrant suspend testClient1`) и начнём посылать пакеты с testServer1 на 10.10.10.1 (testClient2 работает):

    ```console
    [vagrant@testServer1 ~]$ ping 10.10.10.1
    PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
    From 10.10.10.254 icmp_seq=6 Destination Host Unreachable
    From 10.10.10.254 icmp_seq=7 Destination Host Unreachable
    From 10.10.10.254 icmp_seq=8 Destination Host Unreachable
    From 10.10.10.254 icmp_seq=9 Destination Host Unreachable
    ^C
    --- 10.10.10.1 ping statistics ---
    10 packets transmitted, 0 received, +4 errors, 100% packet loss, time 9008ms
    pipe 4
    ```

    После включения testClient1 (`vagrant resume testClient1`):

    ```console
    [vagrant@testServer1 ~]$ ping 10.10.10.1
    PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
    64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=3.06 ms
    64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=0.776 ms
    64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=0.769 ms
    64 bytes from 10.10.10.1: icmp_seq=4 ttl=64 time=0.814 ms
    ^C
    --- 10.10.10.1 ping statistics ---
    4 packets transmitted, 4 received, 0% packet loss, time 3002ms
    rtt min/avg/max/mdev = 0.769/1.356/3.066/0.987 ms
    ```

#### Проверка работы агрегированных каналов

Проверим существующие интерфейсы и убедимся, что team0 поднялся:

```console
[vagrant@inetRouter ~]$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 52:54:00:8a:fe:e6 brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic eth0
       valid_lft 86219sec preferred_lft 86219sec
    inet6 fe80::5054:ff:fe8a:fee6/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast master team0 state UP group default qlen 1000
    link/ether 08:00:27:d5:fc:2a brd ff:ff:ff:ff:ff:ff
4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast master team0 state UP group default qlen 1000
    link/ether 08:00:27:a4:ea:48 brd ff:ff:ff:ff:ff:ff
5: team0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether 08:00:27:d5:fc:2a brd ff:ff:ff:ff:ff:ff
    inet 192.168.255.1/30 brd 192.168.255.3 scope global team0
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fed5:fc2a/64 scope link 
       valid_lft forever preferred_lft forever
```

Посмотрим информацию о нём:

```console
[vagrant@inetRouter ~]$ sudo teamdctl team0 state 
setup:
  runner: activebackup
ports:
  eth1
    link watches:
      link summary: up
      instance[link_watch_0]:
        name: ethtool
        link: up
        down count: 0
  eth2
    link watches:
      link summary: up
      instance[link_watch_0]:
        name: ethtool
        link: up
        down count: 0
runner:
  active port: eth1
```

Поверим отказоустойчивость:

1. Запустим пересылку ICMP-пакетов с centralRouter на inetRouter:

    ```console
    [vagrant@centralRouter ~]$ ping 192.168.255.1
    ```

2. Проверим, что пакеты доходят:

    ```console
    [vagrant@inetRouter ~]$ sudo tcpdump -nnt -i team0 icmp
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on team0, link-type EN10MB (Ethernet), capture size 262144 bytes
    IP 192.168.255.2 > 192.168.255.1: ICMP echo request, id 7235, seq 19, length 64
    IP 192.168.255.1 > 192.168.255.2: ICMP echo reply, id 7235, seq 19, length 64
    IP 192.168.255.2 > 192.168.255.1: ICMP echo request, id 7235, seq 20, length 64
    IP 192.168.255.1 > 192.168.255.2: ICMP echo reply, id 7235, seq 20, length 64
    IP 192.168.255.2 > 192.168.255.1: ICMP echo request, id 7235, seq 21, length 64
    IP 192.168.255.1 > 192.168.255.2: ICMP echo reply, id 7235, seq 21, length 64
    ^C
    6 packets captured
    6 packets received by filter
    0 packets dropped by kernel
    ```

3. Убедимся, что они приходят именно на интерфейс eth1:

    ```console
    [vagrant@inetRouter ~]$ sudo tcpdump -nnt -i eth1 icmp
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on eth1, link-type EN10MB (Ethernet), capture size 262144 bytes
    IP 192.168.255.2 > 192.168.255.1: ICMP echo request, id 7235, seq 43, length 64
    IP 192.168.255.1 > 192.168.255.2: ICMP echo reply, id 7235, seq 43, length 64
    IP 192.168.255.2 > 192.168.255.1: ICMP echo request, id 7235, seq 44, length 64
    IP 192.168.255.1 > 192.168.255.2: ICMP echo reply, id 7235, seq 44, length 64
    IP 192.168.255.2 > 192.168.255.1: ICMP echo request, id 7235, seq 45, length 64
    IP 192.168.255.1 > 192.168.255.2: ICMP echo reply, id 7235, seq 45, length 64
    ^C
    6 packets captured
    6 packets received by filter
    0 packets dropped by kernel
    ```

    На eth2 пусто:

    ```console
    [vagrant@inetRouter ~]$ sudo tcpdump -nnt -i eth2 icmp
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on eth2, link-type EN10MB (Ethernet), capture size 262144 bytes
    ^C
    0 packets captured
    0 packets received by filter
    0 packets dropped by kernel
    ```

4. Выключим eth1:

    ```console
    [vagrant@inetRouter ~]$ sudo ifdown eth1
    [vagrant@inetRouter ~]$ sudo teamdctl team0 state
    setup:
      runner: activebackup
    ports:
      eth2
        link watches:
          link summary: up
          instance[link_watch_0]:
            name: ethtool
            link: up
            down count: 0
    runner:
      active port: eth2
    ```

5. Убедимся, что пакеты приходят на другой интерфейс:

    ```console
    [vagrant@inetRouter ~]$ sudo tcpdump -nnt -i team0 icmp
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on team0, link-type EN10MB (Ethernet), capture size 262144 bytes
    IP 192.168.255.2 > 192.168.255.1: ICMP echo request, id 7235, seq 172, length 64
    IP 192.168.255.1 > 192.168.255.2: ICMP echo reply, id 7235, seq 172, length 64
    IP 192.168.255.2 > 192.168.255.1: ICMP echo request, id 7235, seq 173, length 64
    IP 192.168.255.1 > 192.168.255.2: ICMP echo reply, id 7235, seq 173, length 64
    IP 192.168.255.2 > 192.168.255.1: ICMP echo request, id 7235, seq 174, length 64
    IP 192.168.255.1 > 192.168.255.2: ICMP echo reply, id 7235, seq 174, length 64
    ^C
    6 packets captured
    6 packets received by filter
    0 packets dropped by kernel
    [vagrant@inetRouter ~]$ sudo tcpdump -nnt -i eth2 icmp
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on eth2, link-type EN10MB (Ethernet), capture size 262144 bytes
    IP 192.168.255.2 > 192.168.255.1: ICMP echo request, id 7235, seq 227, length 64
    IP 192.168.255.1 > 192.168.255.2: ICMP echo reply, id 7235, seq 227, length 64
    IP 192.168.255.2 > 192.168.255.1: ICMP echo request, id 7235, seq 228, length 64
    IP 192.168.255.1 > 192.168.255.2: ICMP echo reply, id 7235, seq 228, length 64
    IP 192.168.255.2 > 192.168.255.1: ICMP echo request, id 7235, seq 229, length 64
    IP 192.168.255.1 > 192.168.255.2: ICMP echo reply, id 7235, seq 229, length 64
    ^C
    6 packets captured
    6 packets received by filter
    0 packets dropped by kernel
    ```

<br/>

[Вернуться к списку всех ДЗ](../README.md)
