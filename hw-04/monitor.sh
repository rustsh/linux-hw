#!/bin/bash

### Защита от мультизапуска
lockfile=/tmp/monitor
if ( set -o noclobber; echo "$$" > "$lockfile") 2> /dev/null;
then
    trap 'rm -f "$lockfile"; exit $?' INT TERM EXIT

    ### Основное тело скрипта

    ### Объявление переменных
    timeNow=$(date +%d/%b/%Y:%H:%M:%S)  # Время запуска скрипта
    inputFile=./access-4560-644067.log  # Входной файл
    outputFile=result.log               # Выходной файл
    logFile=lastrun.log                 # Лог-файл с временем последнего выполнения
    emailAddress=root@localhost         # Адрес электронной почты, на который будет приходит результат работы скрипта
    countFrom=$1                        # Количество IP-адресов
    countTo=$2                          # Количество запрашиваемых адресов
    defaultCountFrom=10                 # Количество IP-адресов по умолчанию (если не задано при вызове скрипта)
    defaultCountTo=10                   # Количество запрашиваемых адресов по умолчанию (если не задано при вызове скрипта)

    ### Если скрипт запущен без параметров, задаём переменным количества стандартное значение
    if [[ -z $countFrom ]]
    then
        countFrom=$defaultCountFrom
    fi
    if [[ -z $countTo ]]
    then
        countTo=$defaultCountTo
    fi

    ### Функция вывода отсортированного количества строк с их количеством
    ### $1 — входной текст, $2 — число выводимых строк
    topList() {
        echo "$1" | awk '{ ipcount[$1]++ } END { for (i in ipcount) \
                         { if (ipcount[i] ~ /^[2-4]$|[^1][2-4]$/) case="раза"; else case="раз"; \
                         printf "%s — %d %s\n", i, ipcount[i], case } }' | sort -rnk3 -k1 | head -$2
    }

    ### Считываем время последнего запуска скрипта из файла лога
    ### Если файла нет или он пустой, временем последнего запуска считается время из первой строки входного файла
    if [[ -s $logFile ]]
    then
        lastTime=$(tail -1 $logFile)
    else
        lastTime=$(head -1 $inputFile | cut -d" " -f4 | cut -c2-)
    fi

    ### Выберем данные из интервала между последним временем выполнения скрипта и текущим временем
    logInterval=$(cat "$inputFile" | awk -v lastTime=$lastTime -v timeNow=$timeNow \
                                     '{sub(/\[/,"",$4); if ($4 >= lastTime && $4 < timeNow) print $0}')

    ### Выводим временной диапазон
    echo "Данные за промежуток между $lastTime и $timeNow" > $outputFile
    echo >> $outputFile

    ### Выводим IP-адреса с наибольшим количеством запросов
    echo "Топ $countFrom IP-адресов:" >> $outputFile
    topList "$logInterval" $countFrom >> $outputFile
    echo >> $outputFile

    ### Выводим запрашиваемые адреса с наибольшим количеством запросов
    echo "Топ $countTo запрашиваемых адресов:" >> $outputFile
    # Выводим адрес из запроса, если этот запрос начинается с указания метода (GET, POST и т. д.), иначе выводим прочерк:
    addrList=$(echo "$logInterval" | awk '{ if ($6 ~ /^"[A-Z]+$/) print $7; else print "-" }')
    topList "$addrList" $countTo >> $outputFile
    echo >> $outputFile

    ### Запоминаем все коды возврата
    codeList=$(echo "$logInterval" | awk '{ if ($9 ~ /^[0-9]+$/) print $9; else print $7 }')

    ### Выводим все ошибки
    echo "Присутствующие ошибки:" >> $outputFile
    # Отсортируем все коды возврата, оставим только уникальные значения и при помощи sed удалим коды 2xx и 3xx:
    echo "$codeList" | sort -u | sed '/^[23]/d' >> $outputFile
    echo >> $outputFile

    ### Выводим список всех кодов возврата с указанием их количества
    echo "Коды возврата:" >> $outputFile
    # Посчитаем число уникальных кодов, чтобы передать его как параметр команды head в функции topList:
    codeCount=$(echo "$codeList" | sort -u | wc -l)
    topList "$codeList" $codeCount >> $outputFile

    ### Запишем время выполнения в лог
    if [[ -e $logFile ]]
    then
        echo $timeNow >> $logFile
    else
        echo $timeNow > $logFile
    fi

    ### Отправим результат на почту
    cat $outputFile | mail -s "Result of monitoring at $timeNow" $emailAddress

    ### Закрываем защиту от мультизапуска
    rm -f "$lockfile"
    trap - INT TERM EXIT
else
    echo "Failed to acquire lockfile: $lockfile"
    echo "Held by $(cat $lockfile)"
fi
