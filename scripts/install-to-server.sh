#!/usr/bin/env bash
# Скрипт для установки PRO LAB структуры на сервер
set -euo pipefail

echo "=== Установка PRO LAB на сервер ==="
echo

# Создание структуры на сервере
echo "1. Создание структуры директорий..."
sudo mkdir -p /opt/prolab/hostapd/{2g,5g,common,generated}
sudo mkdir -p /opt/prolab/scripts

# Копирование файлов
echo "2. Копирование конфигов hostapd..."
sudo cp -r hostapd/common/* /opt/prolab/hostapd/common/

echo "3. Копирование скриптов..."
sudo cp scripts/gen-enterprise-variants.sh /opt/prolab/scripts/
sudo cp scripts/ap-run.sh /opt/prolab/scripts/

echo "4. Установка прав на выполнение..."
sudo chmod +x /opt/prolab/scripts/*.sh

echo "5. Генерация конфигов Enterprise вариантов..."
sudo IFACE=wlx001f0566a9c0 \
     OUT=/opt/prolab/hostapd/generated \
     COMMON=/opt/prolab/hostapd/common/radius.conf \
     /opt/prolab/scripts/gen-enterprise-variants.sh

echo
echo "=== Установка завершена ==="
echo "Конфиги находятся в: /opt/prolab/hostapd/generated"
echo
echo "Для запуска AP используйте:"
echo "  /opt/prolab/scripts/ap-run.sh /opt/prolab/hostapd/generated/<конфиг>.conf"
