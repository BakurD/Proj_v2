#!/bin/bash

if ! dpkg -s apache2 >/dev/null 2>&1; then
    # Если пакет Apache2 не установлен, то устанавливаем его
    echo "Apache2 not found, installing..."
    apt-get update
    apt-get -y install apache2
else
    # Если пакет Apache2 уже установлен, то удаляем старый файл index.html
    echo "Apache2 found, removing old index.html..."
    rm -f /var/www/html/index.html
fi

