#!/bin/bash

# Копируем новый файл index.html в директорию /var/www/html/
cp index.html /var/www/html/

# Изменяем права доступа к файлу, чтобы он был доступен через веб-сервер
chown www-data:www-data /var/www/html/index.html
chmod 644 /var/www/html/index.html

