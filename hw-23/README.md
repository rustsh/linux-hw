## Домашнее задание к занятию № 23 — «Мосты, туннели и VPN»  <!-- omit in toc -->

### Оглавление  <!-- omit in toc -->

- [Задание](#Задание)
- [Описание работы](#Описание-работы)
  - [TUN/TAP](#tuntap)
  - [RAS](#ras)
- [Проверка работы](#Проверка-работы)
  - [Проверка TUN/TAP](#Проверка-tuntap)
    - [Проверка TAP](#Проверка-tap)
    - [Проверка TUN](#Проверка-tun)
    - [Разница между TUN и TAP](#Разница-между-tun-и-tap)
  - [Проверка RAS](#Проверка-ras)

### Задание

1. Между двумя виртуальными машинами поднять VPN в режимах:
   - TUN;
   - TAP.

2. Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на виртуальную машину.

### Описание работы

#### TUN/TAP

Все файлы для первого задания находятся в каталоге [tun_tap](tun_tap).

При выполнении команды `vagrant up` поднимаются две виртуальные машины — server и client, после чего запускается их настройка посредством Ansible ([Vagrantfile](tun_tap/Vagrantfile)).

Шаги предварительной настройки:

1. Устанавливаются пакеты openvpn и iperf3.
2. В каталог **/etc/openvpn** копируется файл **server.conf** ([для сервера](tun_tap/provisioning/roles/openvpn/templates/server/server.conf.j2), [для клиента](tun_tap/provisioning/roles/openvpn/templates/client/server.conf.j2)).

    Значение параметра `dev` в файле конфигурации задаётся в [стартовом плейбуке](tun_tap/provisioning/start.yml) в переменной `virt_int`.

3. На сервере генерируется ключ, после чего он копируется в каталог **/etc/openvpn** на стороне клиента.
4. Запускается сервис openvpn@server.

#### RAS

Все файлы для второго задания находятся в каталоге [ras](ras).

При выполнении команды `vagrant up` поднимается одна виртуальная машина, после чего запускается её настройка посредством Ansible ([Vagrantfile](ras/Vagrantfile)).

Шаги предварительной настройки:

1. Устанавливаются пакеты openvpn и easy-rsa.
2. В каталоге **/etc/openvpn** инициализируется PKI.
3. Генерируются сертификаты и ключи для сервера и клиента.
4. В каталог **/etc/openvpn** копируется файл [server.conf](ras/provisioning/roles/openvpn-ras/templates/server.conf.j2).
5. Запускается сервис openvpn@server.
6. На хостовой машине в домашнем каталоге пользователя, запустившего Ansible, создаётся директория **openvpn**, в которую копируются необходимые ключи и сертификаты, а также файл [client.conf](ras/provisioning/roles/openvpn-ras/templates/client.conf.j2).

### Проверка работы

#### Проверка TUN/TAP

Перед запуском необходимо перейти в каталог [tun_tap](tun_tap).

##### Проверка TAP

1. В стартовом плейбуке указать значение переменной `virt_int: tap` и выполнить команду `vagrant up`.
2. В разных терминалах зайти на сервер и на клиент.
3. Убедиться, что виртуальные интерфейсы и новые маршруты созданы:

    на сервере:

    ```console
    [vagrant@localhost ~]$ ip a
    ...
    5: tap0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 100
        link/ether 96:59:a0:1c:8d:ef brd ff:ff:ff:ff:ff:ff
        inet 10.10.10.1/24 brd 10.10.10.255 scope global tap0
           valid_lft forever preferred_lft forever
        inet6 fe80::9459:a0ff:fe1c:8def/64 scope link
           valid_lft forever preferred_lft forever

    [vagrant@localhost ~]$ ip r
    default via 10.0.2.2 dev eth0 proto dhcp metric 100
    10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100
    10.10.10.0/24 dev tap0 proto kernel scope link src 10.10.10.1
    192.168.33.0/24 dev eth1 proto kernel scope link src 192.168.33.10 metric 101

    [vagrant@localhost ~]$ ip l
    ...
    5: tap0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN mode DEFAULT group default qlen 100
        link/ether 96:59:a0:1c:8d:ef brd ff:ff:ff:ff:ff:ff
    ```

    на клиенте:

    ```console
    [vagrant@localhost ~]$ ip a
    ...
    6: tap0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 100
        link/ether 56:07:d6:9e:66:56 brd ff:ff:ff:ff:ff:ff
        inet 10.10.10.2/24 brd 10.10.10.255 scope global tap0
           valid_lft forever preferred_lft forever
        inet6 fe80::5407:d6ff:fe9e:6656/64 scope link
           valid_lft forever preferred_lft forever

    [vagrant@localhost ~]$ ip r
    default via 10.0.2.2 dev eth0 proto dhcp metric 100
    10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100
    10.10.10.0/24 dev tap0 proto kernel scope link src 10.10.10.2
    192.168.33.0/24 dev eth1 proto kernel scope link src 192.168.33.20 metric 101

    [vagrant@localhost ~]$ ip l
    ...
    6: tap0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN mode DEFAULT group default qlen 100
        link/ether 56:07:d6:9e:66:56 brd ff:ff:ff:ff:ff:ff
    ```

4. На сервере выполнить команду `iperf3 -s`.
5. На клиенте запустить передачу пакетов:

    ```console
    [vagrant@localhost ~]$ iperf3 -c 10.10.10.1 -t 60 -i 5
    Connecting to host 10.10.10.1, port 5201
    [  4] local 10.10.10.2 port 37244 connected to 10.10.10.1 port 5201
    [ ID] Interval           Transfer     Bandwidth       Retr  Cwnd
    [  4]   0.00-5.01   sec   120 MBytes   201 Mbits/sec  454    222 KBytes
    [  4]   5.01-10.00  sec   123 MBytes   207 Mbits/sec  133    408 KBytes
    [  4]  10.00-15.00  sec   124 MBytes   207 Mbits/sec  285    424 KBytes
    [  4]  15.00-20.00  sec   125 MBytes   209 Mbits/sec    0    596 KBytes
    [  4]  20.00-25.00  sec   125 MBytes   210 Mbits/sec   92    604 KBytes
    [  4]  25.00-30.00  sec   123 MBytes   207 Mbits/sec  341    475 KBytes
    [  4]  30.00-35.00  sec   124 MBytes   208 Mbits/sec   74    534 KBytes
    [  4]  35.00-40.01  sec   125 MBytes   210 Mbits/sec   82    391 KBytes
    [  4]  40.01-45.00  sec   124 MBytes   209 Mbits/sec  153    240 KBytes
    [  4]  45.00-50.00  sec   125 MBytes   210 Mbits/sec    5    450 KBytes
    [  4]  50.00-55.01  sec   125 MBytes   209 Mbits/sec  236    406 KBytes
    [  4]  55.01-60.00  sec   121 MBytes   202 Mbits/sec  626    206 KBytes
    - - - - - - - - - - - - - - - - - - - - - - - - -
    [ ID] Interval           Transfer     Bandwidth       Retr
    [  4]   0.00-60.00  sec  1.45 GBytes   207 Mbits/sec  2481             sender
    [  4]   0.00-60.00  sec  1.45 GBytes   207 Mbits/sec                  receiver

    iperf Done.
    ```

##### Проверка TUN

1. В стартовом плейбуке указать значение переменной `virt_int: tun` и выполнить команду `vagrant up` (если виртуальные машины уже существуют, то нужно выполнить команду `vagrant provision`).
2. В разных терминалах зайти на сервер и на клиент.
3. Убедиться, что виртуальные интерфейсы и новые маршруты созданы:

    на сервере:

    ```console
    [vagrant@localhost ~]$ ip a
    ...
    6: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 100
        link/none
        inet 10.10.10.1/24 brd 10.10.10.255 scope global tun0
           valid_lft forever preferred_lft forever
        inet6 fe80::8d28:600a:8feb:8da/64 scope link flags 800
           valid_lft forever preferred_lft forever

    [vagrant@localhost ~]$ ip r
    default via 10.0.2.2 dev eth0 proto dhcp metric 100
    10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100
    10.10.10.0/24 dev tun0 proto kernel scope link src 10.10.10.1
    192.168.33.0/24 dev eth1 proto kernel scope link src 192.168.33.10 metric 101

    [vagrant@localhost ~]$ ip l
    ...
    6: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN mode DEFAULT group default qlen 100
        link/none
    ```

    на клиенте:

    ```console
    [vagrant@localhost ~]$ ip a
    ...
    7: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 100
        link/none
        inet 10.10.10.2/24 brd 10.10.10.255 scope global tun0
           valid_lft forever preferred_lft forever
        inet6 fe80::573a:c4ff:b01d:5d3c/64 scope link flags 800
           valid_lft forever preferred_lft forever

    [vagrant@localhost ~]$ ip r
    default via 10.0.2.2 dev eth0 proto dhcp metric 100
    10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100
    10.10.10.0/24 dev tun0 proto kernel scope link src 10.10.10.2
    192.168.33.0/24 dev eth1 proto kernel scope link src 192.168.33.20 metric 101

    [vagrant@localhost ~]$ ip l
    ...
    7: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN mode DEFAULT group default qlen 100
        link/none
    ```

4. На сервере выполнить команду `iperf3 -s`.
5. На клиенте запустить передачу пакетов:

    ```console
    [vagrant@localhost ~]$ iperf3 -c 10.10.10.1 -t 60 -i 5
    Connecting to host 10.10.10.1, port 5201
    [  4] local 10.10.10.2 port 37248 connected to 10.10.10.1 port 5201
    [ ID] Interval           Transfer     Bandwidth       Retr  Cwnd
    [  4]   0.00-5.00   sec   123 MBytes   207 Mbits/sec  571    416 KBytes
    [  4]   5.00-10.00  sec   126 MBytes   211 Mbits/sec  114    408 KBytes
    [  4]  10.00-15.00  sec   127 MBytes   213 Mbits/sec  105    514 KBytes
    [  4]  15.00-20.00  sec   127 MBytes   213 Mbits/sec  194    544 KBytes
    [  4]  20.00-25.00  sec   128 MBytes   215 Mbits/sec   85    517 KBytes
    [  4]  25.00-30.00  sec   128 MBytes   215 Mbits/sec   72    427 KBytes
    [  4]  30.00-35.00  sec   129 MBytes   217 Mbits/sec   71    525 KBytes
    [  4]  35.00-40.01  sec   128 MBytes   214 Mbits/sec  133    416 KBytes
    [  4]  40.01-45.01  sec   128 MBytes   215 Mbits/sec    0    588 KBytes
    [  4]  45.01-50.01  sec   129 MBytes   216 Mbits/sec   11    588 KBytes
    [  4]  50.01-55.00  sec   127 MBytes   214 Mbits/sec    3    600 KBytes
    [  4]  55.00-60.00  sec   127 MBytes   214 Mbits/sec   44    599 KBytes
    - - - - - - - - - - - - - - - - - - - - - - - - -
    [ ID] Interval           Transfer     Bandwidth       Retr
    [  4]   0.00-60.00  sec  1.49 GBytes   214 Mbits/sec  1403             sender
    [  4]   0.00-60.00  sec  1.49 GBytes   213 Mbits/sec                  receiver

    iperf Done.
    ```

##### Разница между TUN и TAP

Основное отличие между TUN и TAP состоит в том, что TAP работает на канальном уровне (L2), а TUN — на сетевом (L3). Это проявляется, в частности, в следующем:

- TAP-интерфейс, в отличие от TUN, имеет MAC-адрес (что видно в выводе команды `ip a`) и может быть использован для создания сетевого моста;
- TAP-интерфейс пропускает широковещательные пакеты (например, по протоколу ARP), что увеличивает объём трафика и повышает нагрузку на сеть.

Таким образом, сервер с поднятым TAP-интерфейсом может использоваться в качестве коммутатора, а с TUN — в качестве маршрутизатора.

Сравнение обоих интерфейсов при помощи программы iperf3 показало следующее:
- объём переданных данных (поле *Transfer*) за один и тот же промежуток времени примерно одинаковый (1,45 Гб для TAP и 1,49 Гб для TUN);
- средняя скорость передачи TCP-пакетов (поле *Bandwidth*) также приблизительно равна в обоих случаях (207 Мбит/c для TAP и 214 Мбит/c для TUN);
- а вот число повторно посылаемых пакетов (поле *Retr*) в случае использования TUN гораздо меньше (1403 против 2481 для TAP);
- объём одновременно переданных данных (поле *Cwnd*) для TUN в среднем больше (512 Кб против 413 Кб для TAP).

#### Проверка RAS

1. Перейти в каталог [ras](ras) и выполнить команду `vagrant up`.
2. Зайти на виртуальную машину и убедиться, что виртуальный интерфейс и новые маршруты созданы:

    ```console
    [vagrant@localhost ~]$ ip a
    ...
    3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
        link/ether 08:00:27:65:65:8d brd ff:ff:ff:ff:ff:ff
        inet 192.168.133.10/24 brd 192.168.133.255 scope global noprefixroute eth1
           valid_lft forever preferred_lft forever
        inet6 fe80::a00:27ff:fe65:658d/64 scope link
           valid_lft forever preferred_lft forever
    5: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 100
        link/none 
        inet 10.10.10.1 peer 10.10.10.2/32 scope global tun0
           valid_lft forever preferred_lft forever
        inet6 fe80::7ecc:2301:6213:67d7/64 scope link flags 800
           valid_lft forever preferred_lft forever

    [vagrant@localhost ~]$ ip r
    default via 10.0.2.2 dev eth0 proto dhcp metric 100
    10.0.2.0/24 dev eth0 proto kernel scope link src 10.0.2.15 metric 100
    10.10.10.0/24 via 10.10.10.2 dev tun0
    10.10.10.2 dev tun0 proto kernel scope link src 10.10.10.1
    192.168.133.0/24 dev eth1 proto kernel scope link src 192.168.133.10 metric 101

    [vagrant@localhost ~]$ ip l
    ...
    5: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN mode DEFAULT group default   qlen 100
        link/none 
    ```

3. С хостовой машины подключиться к виртуальной машине, используя OpenVPN. Для этого на хостовой машине перейти в директорию **openvpn** в домашнем каталоге активного пользователя и выполнить команду:

    ```console
    $ sudo openvpn --config client.conf 
    ```

    Если всё успешно, должно появится сообщение `Initialization Sequence Completed`.

4. Убедиться, что на хостовой машине также создались виртуальный интерфейс и новые маршруты:

    ```console
    $ ip a
    ...
    20: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 100
        link/none 
        inet 10.10.10.6 peer 10.10.10.5/32 scope global tun0
           valid_lft forever preferred_lft forever
        inet6 fe80::f20e:d14e:36b3:d839/64 scope link stable-privacy 
           valid_lft forever preferred_lft forever

    $ ip r
    default via 192.168.1.1 dev wlp3s0 proto dhcp metric 600 
    10.10.10.0/24 via 10.10.10.5 dev tun0 
    10.10.10.5 dev tun0 proto kernel scope link src 10.10.10.6 
    192.168.1.0/24 dev wlp3s0 proto kernel scope link src 192.168.1.11 metric 600 
    192.168.133.0/24 dev vboxnet4 proto kernel scope link src 192.168.133.1

    $ ip l
    ...
    20: tun0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN mode DEFAULT group default    qlen 100
        link/none 
    ```

5. Убедиться, что на хостовой машине доступен внутренний IP-адрес сервера в туннеле:

    ```console
    $ ping -c4 10.10.10.1
    PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
    64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=0.606 ms
    64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=0.809 ms
    64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=0.916 ms
    64 bytes from 10.10.10.1: icmp_seq=4 ttl=64 time=0.840 ms

    --- 10.10.10.1 ping statistics ---
    4 packets transmitted, 4 received, 0% packet loss, time 3014ms
    rtt min/avg/max/mdev = 0.606/0.792/0.916/0.114 ms
    ```

<br/>

[Вернуться к списку всех ДЗ](../README.md)
