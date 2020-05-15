## Домашнее задание к занятию № 5 — «Управление процессами»    <!-- omit in toc -->

Задание: написать свою реализацию `ps ax`, используя анализ **/proc**.

Для выполнения задания написан скрипт [myps.sh](myps.sh)

### Описание работы скрипта

Запоминается список каталогов в **/proc**, состоящий только из цифр — он является списком всех процессов:

```bash
procList=$(ls /proc | egrep '^[0-9]+$')
```

Для каждого процесса из списка (если этот процесс ещё существует) собираются данные:

- **PID** — идентификатор процесса.
    
    Берётся из названия каталога.

- **TTY** — терминал, с которым связан данный процесс.

    Идентификатор терминала содержится в файле **stat** в десятичном формате. Далее он переводится в двоичный формат, из которого извлекаются старший (major) и младший (minor) номера. По этим номерам происходит поиск названия терминала сперва в **/dev/tty\***, а затем, в случае неудачи, в **/dev/pts/\***. Если терминал не найден или его идентификатор в **stat** равен нулю, возвращается вопросительный знак.

- **STAT** — состояние, в котором на данный момент находится процесс.
    
    Содержится в файле **stat**, однако в данном скрипте извлекается из файла **status**, так как в нём содержится не только символ, но и его расшифровка.

- **TIME** — процессорное время, занятое этим процессом.

    Является суммой значений utime (время в режиме пользоваетеля) и stime (время в режиме ядра) из файла **stat**, которые измеряются в тиках (clock ticks). Число тиков в секунду в конктретной системе можно получить, выполнив команду `getconf CLK_TCK`. После этого процессорное время переводится в секунды и выводится в формате "mm:ss".

- **COMMAND** — команда с аргументами, запустившая данный процесс.

    Содержится в файле **cmdline**. Если файл **cmdline** пуст (например, если процесс превратился в зомби), то выводится имя исполняемого файла из файла **stat**.

Вся полученная информация записывается в файл **result.log**.

### Проверка работы скрипта

Примеры вывода содержимого файла **result.log**:

```console
$ cat result.log | head
PID     TTY     STAT            TIME    COMMAND
1       ?       S (sleeping)    5:37    /sbin/init splash
10      ?       S (sleeping)    0:03    [ksoftirqd/0]
1000    ?       S (sleeping)    0:00    /lib/systemd/systemd-timesyncd
1001    ?       S (sleeping)    0:04    /lib/systemd/systemd-resolved
1009    ?       I (idle)        0:00    [kworker/0:0H-kblockd]
1027    ?       S (sleeping)    0:00    /usr/sbin/rsyslogd -n
1028    ?       S (sleeping)    0:10    /usr/sbin/thermald --no-daemon --dbus-enable
1030    ?       S (sleeping)    0:00    /usr/sbin/cron -f
1031    ?       S (sleeping)    0:08    /usr/sbin/irqbalance --foreground
```

```console
$ cat result.log | tail
4966    ?       S (sleeping)    0:01    /usr/lib/zeitgeist/zeitgeist/zeitgeist-fts
521     ?       I (idle)        0:00    [cfg80211]
5680    tty2    S (sleeping)    1:25    /usr/lib/firefox/firefox -contentproc -parentBuildID 20200117190643 -prefsLen 7572 -prefMapSize 211231 -greomni /usr/lib/firefox/omni.ja -appomni /usr/lib/firefox/browser/omni.ja -appdir /usr/lib/firefox/browser 32063 true rdd
6088    tty2    S (sleeping)    11:43   /usr/lib/firefox/firefox -contentproc -childID 28 -isForBrowser -prefsLen 7572 -prefMapSize 211231 -parentBuildID 20200117190643 -greomni /usr/lib/firefox/omni.ja -appomni /usr/lib/firefox/browser/omni.ja -appdir /usr/lib/firefox/browser 32063 true tab
658     ?       I (idle)        0:00    [cryptd]
9       ?       I (idle)        0:00    [mm_percpu_wq]
918     pts/0   S (sleeping)    0:01    bash
9528    ?       S (sleeping)    0:00    /lib/systemd/systemd --user
9529    ?       S (sleeping)    0:00    (sd-pam)
980     tty2    S (sleeping)    13:18   /usr/lib/firefox/firefox -contentproc -childID 10 -isForBrowser -prefsLen 7249 -prefMapSize 211231 -parentBuildID 20200117190643 -greomni /usr/lib/firefox/omni.ja -appomni /usr/lib/firefox/browser/omni.ja -appdir /usr/lib/firefox/browser 32063 true tab
```

### Что можно улучшить

Добавить считывание поля starttime из файла **stat**, чтобы процессы можно было сортировать по времени запуска.

<br/>

[Вернуться к списку всех ДЗ](../README.md)