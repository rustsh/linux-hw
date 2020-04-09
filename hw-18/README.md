## Домашнее задание к занятию № 18 — «Архитектура сетей»    <!-- omit in toc -->

### Оглавление  <!-- omit in toc -->

- [Задание](#Задание)
- [Что сделано](#Что-сделано)
- [Как проверить](#Как-проверить)

### Задание

#### Дано

По ссылке https://github.com/erlong15/otus-linux/tree/network (ветка network) находится Vagrantfile с начальным построением сети:
- inetRouter
- centralRouter
- centralServer

#### Планируемая архитектура

Необходимо построить следующую архитектуру.

Сеть office1:

- 192.168.2.0/26 — dev
- 192.168.2.64/26 — test servers
- 192.168.2.128/26 — managers
- 192.168.2.192/26 — office hardware

Сеть office2:

- 192.168.1.0/25 — dev
- 192.168.1.128/26 — test servers
- 192.168.1.192/26 — office hardware

Сеть central:

- 192.168.0.0/28 — directors
- 192.168.0.32/28 — office hardware
- 192.168.0.64/26 — wifi

```
Office1 ---\
            ---> Central ---> IRouter ---> Internet
Office2 ---/
```

Таким образом, должны получиться следующие серверы:

- inetRouter
- centralRouter
- office1Router
- office2Router
- centralServer
- office1Server
- office2Server

#### Теоретическая часть

- Найти свободные подсети
- Посчитать, сколько узлов в каждой подсети, включая свободные
- Указать broadcast-адрес для каждой подсети
- Проверить, нет ли ошибок при разбиении

#### Практическая часть

- Соединить офисы в сеть согласно схеме и настроить роутинг
- Все серверы и роутеры должны ходить в интернет через inetRouter
- Все серверы должны видеть друг друга
- У всех новых серверов отключить дефолт на нат (eth0), который vagrant поднимает для связи

### Описание работы

Для создания хостов используется Vagrant. В [Vagrantfile](Vagrantfile) описано создание интерфейсов с нужными сетевыми настройками. Для конфигурирования используется Ansible.

[Плейбук](provisioning/start.yml) для предварительной настройки:

```yml
---
- name: Config routing
  hosts: all
  roles:
    - route
```

Структура роли [route](provisioning/roles/route):

```console
route/
├── defaults
│   └── main.yml
├── files
│   └── forwarding.conf
├── handlers
│   └── main.yml
├── tasks
│   ├── default_route.yml
│   └── main.yml
└── templates
    ├── centralRouter
    │   ├── route-eth1.j2
    │   └── route-eth5.j2
    ├── centralServer
    │   └── route-eth1.j2
    ├── inetRouter
    │   └── route-eth1.j2
    ├── office1Router
    │   └── route-eth1.j2
    ├── office1Server
    │   └── route-eth1.j2
    ├── office2Router
    │   └── route-eth1.j2
    ├── office2Server
    │   └── route-eth1.j2
    └── network.j2
```

При запуске плейбука [start.yml](provisioning/start.yml) выполняются следующие шаги:

1. На хосте inetRouter в iptables добавляется правило для маскарадинга исходящих пакетов:

    ```console
    iptables -t nat -A POSTROUTING ! -d 192.168.0.0/16 -o eth0 -j MASQUERADE
    ```

2. В директорию **/etc/sysconfig** копируется файл [network](provisioning/roles/route/templates/network.j2), в котором:

   - явно указано использование сети:

        ```ini
        NETWORKING=yes
        ```

   - указано имя хоста (специфично для каждого сервера):

        ```ini
        HOSTNAME=inetRouter
        ```

   - отключаются маршруты ZEROCONF (для сети 169.254.0.0/16):

        ```ini
        NOZEROCONF=yes
        ```

3. На роутерах включается форвардинг пакетов: в каталог **/etc/sysctl.d** добавляется файл **forwarding.conf**, содержащий следующую строчку:

    ```ini
    net.ipv4.conf.all.forwarding = 1
    ```

4. На всех хостах, кроме inetRouter, на интерфейсе `eth0` отключается маршрут default: выполняется команда `ip route del default`, в файл **/etc/sysconfig/network-scripts/ifcfg-eth0** добавляется параметр `DEFROUTE=no`.
5. На всех хостах, кроме inetRouter, на интерфейсе `eth1` назначается шлюз: в файл **/etc/sysconfig/network-scripts/ifcfg-eth1** добавляется параметр вида `GATEWAY=192.168.0.1`. Адреса шлюзов для каждой сети и для каждого хоста прописаны в файле [default/main.yml](provisioning/roles/route/defaults/main.yml) роли [route](provisioning/roles/route).
6. Настраивается маршрутизация:

    - на каждый хост в каталог **/etc/sysconfig/network-scripts** копируется файл **route-eth1** с прописанными там маршрутами;
    - на хост centralRouter дополнительно копируется файл **route-eth5**, так как он связан с офисными роутерами через интерфейс `eth5`;
    - на всех хостах, кроме inetRouter, в файле **route-eth1** прописан только маршрут по умочанию до вышестоящего роутера, т. е. строка вида:

        ```
        default via 192.168.0.1
        ```

    - на хосте inetRouter в файле **route-eth1** прописаны маршруты до внутренних сетей через centralRouter:

        ```
        192.168.254.0/28 via 192.168.255.2
        192.168.0.0/28 via 192.168.255.2
        192.168.2.0/26 via 192.168.255.2
        192.168.1.0/25 via 192.168.255.2
        ```

    - на хосте centralRouter в файле **route-eth5** прописаны маршруты до сетей office1 и office2 через офисные роутеры:

        ```
        192.168.2.0/26 via 192.168.254.2
        192.168.1.0/25 via 192.168.254.3
        ```

7. После поднятия хостов сервис network находится в статусе `failed` c ошибкой `Connection activation failed: No suitable device found for this connection` для интерфейса `eth0` из-за NetworkManager. При выполнении команды `systemctl restart network` сервис network запускается, но маршруты из файлов **route-eth\*** не подтягиваются. Чтобы избежать этого, сервиc network запускается отдельной командой (после чего рестарт работает нормально).
8.  Отключается сервис NetworkManager, так как, во-первых, сеть настраивается вручную, а во-вторых, он приводит к ошибке, описанной в предыдущем пункте (ошибка повторяется при перезагрузке сервера).

    Альтернативный вариант: во всех файлах **/etc/sysconfig/network-scripts/ifcfg-eth\*** указать параметр `NM_CONTROLLED=no`.

9.  После внесения всех изменений перезапускается сервис network.

Итоговая конфигурация выглядит следующим образом:

![](images/net_scheme.png)

### Проверка работы



### Теоретическая часть



<br/>

[Вернуться к списку всех ДЗ](../README.md)