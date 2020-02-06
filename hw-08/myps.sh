#!/usr/bin/env bash

### Функция, на вход которой подаётся PID процесса, а на выход — информация о процессе
procInfo() {
    # получим имя терминала
    ttyName=$(getTTY $1)
    # получим статус процесса
    status=$(cat /proc/$1/status | grep State | cut -f2)
    # получим процессорное время
    procTime=$(getTime $1)
    # получим командную строку, запустившую процесс
    cmd=$(cat /proc/$1/cmdline | tr "\0" " ")
    # если файл cmdline пустой, то вместо команды выведем имя исполняемого файла из stat,
    # оставив только значение в скобках (awk может сработать неправильно из-за пробелов внутри скобок)
    if [[ -z $cmd ]]
    then
        cmd=$(cat /proc/$1/stat | sed 's/.*(//' | sed 's/).*//')
        cmd="[${cmd}]"
    fi
    # выводим PID, терминал, статус, время процессора и командную строку, разделённые табуляцией
    echo -e $1\\t$ttyName\\t$status\\t$procTime\\t$cmd
}

### Функция, на вход которой подаётся PID процесса, а на выход — название терминала
getTTY() {
    # отсечём из строки stat первые два поля, удалив всё до закрывающей скобки с пробелом включительно
    # (awk может сработать неправильно из-за пробелов внутри скобок),
    # и заберём из полученной строки пятое поле (десятичное значение tty_nr)
    ttynr=$(cat /proc/$1/stat | sed 's/.*) //' | cut -d" " -f5)
    # десятичное значение переводится в двоичное, в котором биты 15..8 означают старший номер (major) устройства,
    # а биты 32..20 и 7..0 — младший номер (minor)
    ttynr=$(echo "obase=2;$ttynr" | bc)
    # если tty_nr или major равны нулю, то вместо названия терминала возвращается знак вопроса
    if [[ $ttynr -eq 0 || ${#ttynr} -le 8 ]]
    then
        ttyName="?"
    else
        # дополняем двоичное представление tty_nr ведущими нулями в зависимости от длины
        if [[ ${#ttynr} -le 16 ]]
        then
            ttynr=$(printf "%016s" $ttynr | tr " " 0)
        else
            ttynr=$(printf "%032s" $ttynr | tr " " 0)
        fi
        # получаем старший и младший номера устройства
        major=$(getMajor $ttynr)
        minor=$(getMinor $ttynr)
        # ищем по старшему и младшему номерам нужный терминал в /dev
        ttyName=$(ls -l /dev/tty* | awk -v major=$major -v minor=$minor '{if ($5==major"," && $6==minor) print $10}' | sed 's;/dev/;;')
        if [[ -z $ttyName ]]
        then
            ttyName=$(ls -l /dev/pts/* | awk -v major=$major -v minor=$minor '{if ($5==major"," && $6==minor) print $10}' | sed 's;/dev/;;')
            if [[ -z $ttyName ]]
            then
                ttyName="?"
            fi
        fi
    fi
    echo $ttyName
}

### Функция для получения major в десятичном формате из двоичного представления tty_nr
getMajor() {
    # оставляем биты 15..8
    str=$1
    majorBin=$(echo ${str: -16:8})
    # переводим в десятичный формат
    major=$(echo "ibase=2;$majorBin" | bc)
    echo $major
}

### Функция для получения minor в десятичном формате из двоичного представления tty_nr
getMinor() {
    # запоминаем биты 7..0
    str=$1
    minorBin=$(echo ${str: -8})
    # если биты 31..20 непустые, то добавляем их к minorBin
    if [[ ${#str} -eq 32 ]]
    then
        minorAdd=$(echo ${str:0:12})
        minorBin=$minorAdd$minorBin
    fi
    # переводим в десятичный формат
    minor=$(echo "ibase=2;$minorBin" | bc)
    echo $minor
}

### Функция, на вход которой подаётся PID процесса, а на выход — время CPU, затраченное на процесс
getTime() {
    # отсечём из строки stat первые два поля, удалив всё до закрывающей скобки с пробелом включительно
    # (awk может сработать неправильно из-за пробелов внутри скобок),
    # заберём из полученной строки utime (время в режиме пользоваетеля) и stime (время в режиме ядра)
    # и получим общее время процессора в тиках (clock ticks), сложив их
    timeProc=$(cat /proc/$1/stat | sed 's/.*) //' | cut -d" " -f '12 13' | tr " " + | bc)
    # получим число тиков в секунду, установленное в системе
    hz=$(getconf CLK_TCK)
    # переведём процессорное время в секунды (отбросив при этом дробную часть)
    timeProcS=$(($timeProc / $hz))
    # выделим целое число минут
    timeProcM=$(($timeProcS / 60))
    # найдём оставшееся число секунд
    timeProcS=$(($timeProcS % 60))
    # выведем время в строке в формате "mm:ss"
    printf "%d:%02d" $timeProcM $timeProcS
}

# выведем шапку
echo -e PID\\tTTY\\tSTAT\\t\\tTIME\\tCOMMAND > result.log

# получим список всех процессов
procList=$(ls /proc | egrep '^[0-9]+$')

# циклично выведем информацию о каждом процессе, если он ещё существует
for pid in $(echo $procList)
do
    if [[ -e /proc/$pid ]]
    then
        procInfo $pid >> result.log
    fi
done