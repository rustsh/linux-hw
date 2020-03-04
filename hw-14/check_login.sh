#!/usr/bin/env bash

check=$(groups $PAM_USER | awk '{ for (k=3; k<=NF; k++) {if ($k=="admin") print $k } }')

if [[ -z $check ]]
then
    if [[ $(date +%a) = "Sat" || $(date +%a) = "Sun" ]]
    then
        exit 1
    else
        exit 0
    fi
fi