## Домашнее задание к занятию № 20 — «Сетевые пакеты. VLAN'ы. LACP»  <!-- omit in toc -->

### Оглавление  <!-- omit in toc -->

- [Задание](#Задание)
- [Описание работы](#Описание-работы)
  - [Подготовка стенда](#Подготовка-стенда)
  - [VLAN](#vlan)
  - [LACP](#lacp)
- [Проверка работы](#Проверка-работы)

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

Между centralRouter и inetRouter "пробросить" 2 линка (общая внутренняя сеть) и объединить их в bond. Проверить работу c отключением интерфейсов.

### Описание работы

#### Подготовка стенда

Для работы используется стенд из [домашнего задания по теме «Архитектура сетей»](../hw-18) со следующими изменениями:

1. Удалены неиспользуемые хосты: office2Server, office2Router, office1Server, centralServer. Из роли [route](provisioning/roles/route) удалены все соответствующие [шаблоны](provisioning/roles/route/templates).
2. На роутерах удалены все неиспользуемые интерфейсы. В связи с этим шаблон **route-eth5.j2** для centralRouter заменён на **route-eth2.j2**
3. Из файлов **/etc/sysconfig/network-scripts/route-eth\*** удалены маршруты до несуществующих сетей.
4. Из файла [defaults/main.yml](provisioning/roles/route/defaults/main.yml) роли [route](provisioning/roles/route) удалены параметры неиспользуемых сетей.
5. Добавлены новые серверы

#### VLAN



#### LACP



### Проверка работы



<br/>

[Вернуться к списку всех ДЗ](../README.md)
