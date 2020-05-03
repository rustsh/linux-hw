## Домашнее задание к занятию № 26 — «DNS/DHCP — настройка и обслуживание»  <!-- omit in toc -->

### Оглавление  <!-- omit in toc -->

- [Задание](#Задание)
- [Описание работы](#Описание-работы)
- [Проверка работы](#Проверка-работы)
  - [Проверка SELinux](#Проверка-selinux)
  - [Доступность зон на client1](#Доступность-зон-на-client1)
  - [Доступность зон на client2](#Доступность-зон-на-client2)

### Задание

Взять за основу стенд https://github.com/erlong15/vagrant-bind. Добавить еще один сервер — client2. Завести в зоне dns.lab имена:
- web1 — смотрит на client1;
- web2 — смотрит на client2.

Завести еще одну зону — newdns.lab. Завести в ней запись www, которая смотрит на обоих клиентов.

Настроить split-dns:
- client1 видит обе зоны, но в зоне dns.lab — только web1;
- client2 видит только dns.lab.

Задание со *: настроить всё без выключения SELinux.

### Описание работы

За основу взят стэнд https://github.com/erlong15/vagrant-bind, в него внесены следующие изменения:

1. В [Vagrantfile](Vagrantfile) добавлен ещё один клиент:

    ```ruby
    config.vm.define "client2" do |client2|
      client2.vm.network "private_network", ip: "192.168.50.16", virtualbox__intnet: "dns"
      client2.vm.hostname = "client2"
    end
    ```

2. Скрипты предварительной настройки переписаны с использованием ролей и параметризированных шаблонов.
3. Зона dns.lab разделена на два файла: [client1.dns.lab](provisioning/roles/dns-servers/files/zones/client1.dns.lab) и [client2.dns.lab](provisioning/roles/dns-servers/files/zones/client2.dns.lab) — в соответствии с заданием.
4. Добавлен [файл зоны newdns.lab](provisioning/roles/dns-servers/files/zones/newdns.lab).
5. Зона ddns.lab удалена, так как она нигде не используется.
6. Файлы зон перемещены из каталога **/etc/named** в каталог **/var/named/zones** на master-сервере и **/var/named/slaves** на slave-сервере.
7. В конфигурационных файлах **/etc/named.conf** на [master-сервере](provisioning/roles/dns-servers/templates/master-named.conf.j2) и [slave-сервере](provisioning/roles/dns-servers/templates/slave-named.conf.j2) настроены представления (views), разделяющие использование зон для client1, client2 и всех остальных.
8. SELinux по умолчанию сконфигурирован таким образом, что не требует дополнительной настройки (подробнее можно прочитать [в документации](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/selinux_users_and_administrators_guide/chap-managing_confined_services-berkeley_internet_name_domain#sect-Managing_Confined_Services-BIND-BIND_and_SELinux)).

### Проверка работы

Чтобы создать и сконфигурировать все машины, достаточно выполнить команду `vagrant up`.

#### Проверка SELinux

На ns01 (master):

```console
[root@ns01 ~]# sestatus
SELinux status:                 enabled
SELinuxfs mount:                /sys/fs/selinux
SELinux root directory:         /etc/selinux
Loaded policy name:             targeted
Current mode:                   enforcing
Mode from config file:          enforcing
Policy MLS status:              enabled
Policy deny_unknown status:     allowed
Max kernel policy version:      31

[root@ns01 ~]# ls -Z /var/named
drwxrwx---. named named system_u:object_r:named_cache_t:s0 data
drwxrwx---. named named system_u:object_r:named_cache_t:s0 dynamic
-rw-r-----. root  named system_u:object_r:named_conf_t:s0 named.ca
-rw-r-----. root  named system_u:object_r:named_zone_t:s0 named.empty
-rw-r-----. root  named system_u:object_r:named_zone_t:s0 named.localhost
-rw-r-----. root  named system_u:object_r:named_zone_t:s0 named.loopback
drwxrwx---. named named system_u:object_r:named_cache_t:s0 slaves
drwxr-xr-x. root  named unconfined_u:object_r:named_zone_t:s0 zones
```

На ns02 (slave):

```console
[root@ns02 ~]# sestatus
SELinux status:                 enabled
SELinuxfs mount:                /sys/fs/selinux
SELinux root directory:         /etc/selinux
Loaded policy name:             targeted
Current mode:                   enforcing
Mode from config file:          enforcing
Policy MLS status:              enabled
Policy deny_unknown status:     allowed
Max kernel policy version:      31

[root@ns02 ~]# ls -Z /var/named/slaves/
-rw-r--r--. named named system_u:object_r:named_cache_t:s0 client1.dns.lab
-rw-r--r--. named named system_u:object_r:named_cache_t:s0 client2.dns.lab
-rw-r--r--. named named system_u:object_r:named_cache_t:s0 dns.lab.rev
-rw-r--r--. named named system_u:object_r:named_cache_t:s0 newdns.lab
```

#### Доступность зон на client1

```console
[vagrant@client1 ~]$ ping -c2 web1
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client1 (192.168.50.15): icmp_seq=1 ttl=64 time=0.010 ms
64 bytes from client1 (192.168.50.15): icmp_seq=2 ttl=64 time=0.049 ms

--- web1.dns.lab ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1003ms
rtt min/avg/max/mdev = 0.010/0.029/0.049/0.020 ms
```

```console
[vagrant@client1 ~]$ ping -c2 web2
ping: web2: Name or service not known
```

```console
[vagrant@client1 ~]$ ping -c2 www.newdns.lab
PING www.newdns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from client1 (192.168.50.15): icmp_seq=1 ttl=64 time=0.014 ms
64 bytes from client1 (192.168.50.15): icmp_seq=2 ttl=64 time=0.048 ms

--- www.newdns.lab ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1005ms
rtt min/avg/max/mdev = 0.014/0.031/0.048/0.017 ms
```

```console
[vagrant@client1 ~]$ dig web2.dns.lab 

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-16.P2.el7_8.2 <<>> web2.dns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 60481
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;web2.dns.lab.                  IN      A

;; AUTHORITY SECTION:
dns.lab.                600     IN      SOA     ns01.dns.lab. root.dns.lab. 2711201407 3600 600 86400 600

;; Query time: 1 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Sun May 03 15:22:31 UTC 2020
;; MSG SIZE  rcvd: 87
```

```console
[vagrant@client1 ~]$ dig www.newdns.lab 

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-16.P2.el7_8.2 <<>> www.newdns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 25175
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 2, AUTHORITY: 2, ADDITIONAL: 3

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.newdns.lab.                        IN      A

;; ANSWER SECTION:
www.newdns.lab.         3600    IN      A       192.168.50.15
www.newdns.lab.         3600    IN      A       192.168.50.16

;; AUTHORITY SECTION:
newdns.lab.             3600    IN      NS      ns02.dns.lab.
newdns.lab.             3600    IN      NS      ns01.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.           3600    IN      A       192.168.50.10
ns02.dns.lab.           3600    IN      A       192.168.50.11

;; Query time: 1 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Sun May 03 15:22:39 UTC 2020
;; MSG SIZE  rcvd: 149
```

#### Доступность зон на client2

```console
[vagrant@client2 ~]$ ping -c2 web1
PING web1.dns.lab (192.168.50.15) 56(84) bytes of data.
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=1 ttl=64 time=0.511 ms
64 bytes from 192.168.50.15 (192.168.50.15): icmp_seq=2 ttl=64 time=0.801 ms

--- web1.dns.lab ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 0.511/0.656/0.801/0.145 ms
```

```console
[vagrant@client2 ~]$ ping -c2 web2
PING web2.dns.lab (192.168.50.16) 56(84) bytes of data.
64 bytes from client2 (192.168.50.16): icmp_seq=1 ttl=64 time=0.035 ms
64 bytes from client2 (192.168.50.16): icmp_seq=2 ttl=64 time=0.047 ms

--- web2.dns.lab ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 0.035/0.041/0.047/0.006 ms
```

```console
[vagrant@client2 ~]$ ping -c2 www.newdns.lab
ping: www.newdns.lab: Name or service not known
```

```console
[vagrant@client2 ~]$ dig web2.dns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-16.P2.el7_8.2 <<>> web2.dns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 63052
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 2, ADDITIONAL: 3

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;web2.dns.lab.                  IN      A

;; ANSWER SECTION:
web2.dns.lab.           3600    IN      A       192.168.50.16

;; AUTHORITY SECTION:
dns.lab.                3600    IN      NS      ns01.dns.lab.
dns.lab.                3600    IN      NS      ns02.dns.lab.

;; ADDITIONAL SECTION:
ns01.dns.lab.           3600    IN      A       192.168.50.10
ns02.dns.lab.           3600    IN      A       192.168.50.11

;; Query time: 1 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Sun May 03 15:59:57 UTC 2020
;; MSG SIZE  rcvd: 127
```

```console
[vagrant@client2 ~]$ dig www.newdns.lab

; <<>> DiG 9.11.4-P2-RedHat-9.11.4-16.P2.el7_8.2 <<>> www.newdns.lab
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 39121
;; flags: qr rd ra ad; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;www.newdns.lab.                        IN      A

;; AUTHORITY SECTION:
.                       10784   IN      SOA     a.root-servers.net. nstld.verisign-grs.com. 2020050300 1800 900 604800 86400

;; Query time: 1 msec
;; SERVER: 192.168.50.10#53(192.168.50.10)
;; WHEN: Sun May 03 16:00:03 UTC 2020
;; MSG SIZE  rcvd: 118
```

<br/>

[Вернуться к списку всех ДЗ](../README.md)
