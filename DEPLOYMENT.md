# Руководство по развертыванию PRO LAB на сервере

## 🎯 Цель

Развернуть PRO LAB структуру на сервере для тестирования Enterprise WiFi конфигураций.

## 📋 Предварительные требования

### 1. Установленное ПО

```bash
# Обновить систему
sudo apt update && sudo apt upgrade -y

# Установить необходимые пакеты
sudo apt install -y hostapd freeradius git
```

### 2. Настройка FreeRADIUS

Убедитесь, что FreeRADIUS настроен для работы с hostapd:

#### Файл: `/etc/freeradius/3.0/clients.conf`

Добавить или проверить:

```conf
client localhost {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
    nas_type = other
}
```

#### Файл: `/etc/freeradius/3.0/users`

Добавить тестового пользователя:

```conf
testuser    Cleartext-Password := "testpass"
            Reply-Message := "Hello, %{User-Name}"
```

#### Перезапустить FreeRADIUS

```bash
sudo systemctl restart freeradius
sudo systemctl enable freeradius
```

### 3. Проверка Wi-Fi адаптера

```bash
# Найти имя Wi-Fi интерфейса
iw dev

# Или
ip link show

# Проверить режимы поддержки
iw list | grep -A 10 "Supported interface modes"
```

Должен поддерживать режим `AP` (Access Point).

## 🚀 Установка PRO LAB

### Метод 1: Автоматическая установка (рекомендуется)

```bash
# Склонировать репозиторий
cd /tmp
git clone <ваш-github-repo-url> prolab_ap
cd prolab_ap

# Если нужно изменить интерфейс Wi-Fi, отредактируйте скрипты
# или используйте переменную окружения IFACE

# Запустить установку
sudo ./scripts/install-to-server.sh
```

### Метод 2: Ручная установка

```bash
# Склонировать репозиторий
git clone <ваш-github-repo-url> /tmp/prolab_ap
cd /tmp/prolab_ap

# Создать структуру
sudo mkdir -p /opt/prolab/hostapd/{2g,5g,common,generated}
sudo mkdir -p /opt/prolab/scripts

# Скопировать файлы
sudo cp -r hostapd/common/* /opt/prolab/hostapd/common/
sudo cp scripts/*.sh /opt/prolab/scripts/
sudo chmod +x /opt/prolab/scripts/*.sh

# Сгенерировать конфиги
cd /opt/prolab
sudo ./scripts/gen-enterprise-variants.sh
```

## ⚙️ Настройка Wi-Fi интерфейса

### Отключить NetworkManager для Wi-Fi

Создать файл `/etc/NetworkManager/conf.d/unmanaged-wifi.conf`:

```ini
[keyfile]
unmanaged-devices=interface-name:wlx001f0566a9c0
```

Замените `wlx001f0566a9c0` на имя вашего интерфейса.

```bash
# Перезапустить NetworkManager
sudo systemctl restart NetworkManager

# Проверить статус интерфейса
nmcli dev status
```

### Альтернатива: временное отключение управления

```bash
sudo nmcli dev set wlx001f0566a9c0 managed no
```

Это нужно делать каждый раз перед запуском hostapd.

## 🔍 Проверка установки

```bash
# Проверить структуру
ls -la /opt/prolab/

# Проверить сгенерированные конфиги
ls -1 /opt/prolab/hostapd/generated/

# Должно быть 14 конфигов (7 для 2.4GHz + 7 для 5GHz)
ls -1 /opt/prolab/hostapd/generated/ | wc -l
```

## 🎬 Запуск тестирования

### Терминал 1: FreeRADIUS в debug режиме

```bash
# Остановить сервис
sudo systemctl stop freeradius

# Запустить в debug режиме
sudo freeradius -X
```

Оставьте этот терминал открытым для мониторинга RADIUS запросов.

### Терминал 2: hostapd

```bash
# Посмотреть список конфигов
ls -1 /opt/prolab/hostapd/generated/

# Запустить первый вариант (WPA2-EAP, PMF off, 2.4GHz)
sudo /opt/prolab/scripts/ap-run.sh /opt/prolab/hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF0.conf
```

### Терминал 3: Сканирование (опционально)

На другом устройстве или в третьем терминале:

```bash
# Сканирование с помощью iw
sudo iw dev wlan0 scan | grep -A 20 "LAB-"

# Или с помощью nmcli
nmcli dev wifi list
```

## 📊 Прогон всех конфигураций

```bash
# Создать скрипт для последовательного прогона
sudo tee /opt/prolab/scripts/test-all-configs.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -e

CONFIGS_DIR="/opt/prolab/hostapd/generated"
DURATION=${1:-30}  # Время работы каждой конфигурации в секундах

for conf in "$CONFIGS_DIR"/*.conf; do
    echo "==================================="
    echo "Testing: $(basename $conf)"
    echo "==================================="
    
    # Запустить AP
    timeout ${DURATION}s sudo /opt/prolab/scripts/ap-run.sh "$conf" || true
    
    echo "Waiting 5 seconds before next config..."
    sleep 5
done

echo "All configs tested!"
EOF

sudo chmod +x /opt/prolab/scripts/test-all-configs.sh

# Запустить тест всех конфигов (каждый работает 30 секунд)
/opt/prolab/scripts/test-all-configs.sh 30
```

## 🔧 Настройка параметров

### Изменить Wi-Fi интерфейс

Отредактируйте файлы:
- `/opt/prolab/scripts/gen-enterprise-variants.sh` — строка `IFACE="${IFACE:-wlx001f0566a9c0}"`
- `/opt/prolab/scripts/ap-run.sh` — строка с `nmcli dev set`

Или используйте переменную окружения:

```bash
export IFACE=wlan0
sudo -E /opt/prolab/scripts/gen-enterprise-variants.sh
```

### Изменить канал или частоту

Отредактируйте `/opt/prolab/scripts/gen-enterprise-variants.sh`:

```bash
# Для 2.4 GHz (каналы 1-13)
CH_24="6"

# Для 5 GHz (каналы 36, 40, 44, 48 или 149-165 в зависимости от региона)
CH_5="36"
```

После изменения перегенерируйте конфиги:

```bash
sudo rm -f /opt/prolab/hostapd/generated/*.conf
sudo /opt/prolab/scripts/gen-enterprise-variants.sh
```

### Изменить RADIUS настройки

Отредактируйте `/opt/prolab/hostapd/common/radius.conf`.

## 🐛 Решение проблем

### hostapd не запускается

**Проблема:** `Could not configure driver mode`

**Решение:**
```bash
# Проверить, что интерфейс не используется
sudo airmon-ng check kill
sudo rfkill unblock wifi

# Проверить режимы поддержки
iw phy | grep -A 10 "Supported interface modes"
```

### RADIUS аутентификация не работает

**Проблема:** Клиенты не могут подключиться

**Решение:**
```bash
# Проверить логи FreeRADIUS в терминале с freeradius -X
# Должны быть сообщения о получении Access-Request

# Проверить настройки client в FreeRADIUS
sudo grep -r "testing123" /etc/freeradius/3.0/

# Тестовый запрос к RADIUS
echo "User-Name=testuser,User-Password=testpass" | \
  radclient -x 127.0.0.1:1812 auth testing123
```

### NetworkManager перехватывает интерфейс

**Проблема:** hostapd падает, NetworkManager управляет интерфейсом

**Решение:**
```bash
# Постоянно отключить управление
sudo nano /etc/NetworkManager/conf.d/unmanaged-wifi.conf
# Добавить: [keyfile]
#           unmanaged-devices=interface-name:wlx001f0566a9c0

sudo systemctl restart NetworkManager
```

### Некоторые конфиги не работают

**Проблема:** GCMP или Suite-B конфиги не запускаются

**Решение:** Это нормально, не все драйверы поддерживают все cipher suites. Просто пропустите эти конфиги.

```bash
# Проверить поддерживаемые cipher suites
iw list | grep -A 10 "Supported Cipher"
```

## 📝 Логирование

### Сохранить логи hostapd

```bash
# Запустить с перенаправлением в файл
sudo /opt/prolab/scripts/ap-run.sh /opt/prolab/hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF0.conf 2>&1 | tee hostapd.log
```

### Проверить системные логи

```bash
sudo journalctl -u freeradius -f
sudo journalctl -u hostapd -f
```

## 🔄 Обновление с GitHub

```bash
cd /tmp
git clone <ваш-github-repo-url> prolab_ap_new
cd prolab_ap_new
sudo ./scripts/install-to-server.sh
```

## 🎓 Дополнительная информация

- [hostapd documentation](https://w1.fi/hostapd/)
- [FreeRADIUS documentation](https://freeradius.org/documentation/)
- [802.11w (PMF) specification](https://en.wikipedia.org/wiki/IEEE_802.11w-2009)

## 📞 Поддержка

При возникновении проблем сохраните:
1. Вывод `iw list`
2. Логи hostapd
3. Логи FreeRADIUS
4. Конфигурацию, которая не работает
