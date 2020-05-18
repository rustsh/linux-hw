## Домашнее задание к занятию № 12 — «SELinux»  <!-- omit in toc -->

### Оглавление  <!-- omit in toc -->



### Задание 1

Запустить Nginx на нестандартном порту тремя разными способами:
  - переключатели setsebool;
  - добавление нестандартного порта в имеющийся тип;
  - формирование и установка модуля SELinux.

#### Предварительная настройка стенда

Все файлы для первого задания находятся в каталоге [task_one](task_one).

Для создания стенда используется Vagrant ([Vagrantfile](task_one/Vagrantfile)). Для настройки стенда создана Ansible-роль [nginx](task_one/provisioning/roles/nginx).

Предварительная настройка включает в себя следующие шаги:

1. Устанавливаются нужные для работы с SELinux пакеты: policycoreutils-python, setroubleshoot, setools.
2. В тип http_port_t добавляется нестандартный порт 200.
3. Устанавливается и запускается Nginx, который слушает порты 80 и 200 ([default.conf](task_one/provisioning/roles/nginx/files/default.conf)).

В конфигурационном файле Nginx также указан для прослушивания порт 300, но строка с ним закомментирована — соответствующий модуль SELinux будем устанавливать вручную.

Чтобы создать и сконфигурировать стенд, достаточно выполнить команду `vagrant up`.

Для проверки работы необходимо на хостовой системе в браузере перейти на страницу http://10.10.10.10/ с указанием соответствующего порта (IP-адрес задаётся в [Vagrantfile](task_one/Vagrantfile)).

#### Добавление нестандартного порта в имеющийся тип

Команда для добавления нестандартного порта в имеющийся тип:

```console
[root@webserver ~]# semanage port -a -t http_port_t -p tcp 200
```

Таск Ansible:

```yml
- name: Allow Nginx to listen on tcp port 200
  seport:
    ports: 200
    proto: tcp
    setype: http_port_t
    state: present
```

Подключимся к виртуальной машине и убедимся, что порт добавлен в тип:

```console
[root@webserver ~]# semanage port -l | grep http_port
http_port_t                    tcp      200, 80, 81, 443, 488, 8008, 8009, 8443, 9000
```

Убедимся, что Nginx слушает порт 200:

![]

#### Формирование и установка модуля SELinux

1. Подключимся к виртуальной машине командой `vagrant ssh` и залогинимся под пользователем root:

    ```console
    [vagrant@webserver ~]$ sudo -i
    ```

2. Откроем файл **/etc/nginx/conf.d/default.conf** и раскомментируем строку `listen 300;`. Сохраним и закроем файл.
3. Перезапустим службу nginx, ожидаемо получим сообщение об ошибке:

    ```console
    [root@webserver ~]# systemctl restart nginx
    Job for nginx.service failed because the control process exited with error code. See "systemctl status nginx.service" and "journalctl -xe" for details.
    ```

4. Чтобы получить подробную информацию об ошибке, а также способы её решения, можно выполнить команду `sealert -a /var/log/audit/audit.log` (входит в состав пакета setroubleshoot).
5. При помощи alert2allow создадим новый модуль SELinux, разрешающий Nginx слушать порт 300 (необходимые команды содержатся в выводе sealert):

    ```console
    [root@webserver ~]# ausearch -c 'nginx' --raw | audit2allow -M my-nginx
    ******************** IMPORTANT ***********************
    To make this policy package active, execute:

    semodule -i my-nginx.pp
    ```

6. Проверим, что в текущем каталоге появились нужные файлы:

    ```console
    [root@webserver ~]# ls my-nginx*
    my-nginx.pp  my-nginx.te
    ```

7. Установим только что созданный модуль SELinux:

    ```console
    [root@webserver ~]# semodule -i my-nginx.pp
    ```

8. Проверим, что модуль установлен:

    ```console
    [root@webserver ~]# semodule -l | grep my-nginx
    my-nginx        1.0
    ```

9. Перезапустим Nginx командой `systemctl restart nginx`.
10. Убедимся, что теперь Nginx работает и слушает порт 300:

    ![]

### Задание 2

Обеспечить работоспособность приложения при включенном SELinux.
  - развернуть приложенный стенд: https://github.com/mbfx/otus-linux-adm/blob/master/selinux_dns_problems/;
  - выяснить причину неработоспособности механизма обновления зоны (см. README);
  - предложить решение (или решения) для данной проблемы;
  - выбрать одно из решений для реализации, предварительно обосновав выбор;
  - реализовать выбранное решение и продемонстрировать его работоспособность.



<br/>

[Вернуться к списку всех ДЗ](../README.md)
