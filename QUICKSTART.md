# 🚀 Быстрый старт PRO LAB

## На сервере (после установки)

### 1️⃣ Запустить FreeRADIUS
```bash
sudo freeradius -X
```

### 2️⃣ Запустить AP с конфигом
```bash
# Список всех конфигов
ls -1 /opt/prolab/hostapd/generated/

# Запустить (пример)
/opt/prolab/scripts/ap-run.sh /opt/prolab/hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF0.conf
```

### 3️⃣ Остановить
`Ctrl+C`

---

## Локально (в Git репозитории)

### Установка на сервер
```bash
git clone <repo-url> /tmp/prolab_ap
cd /tmp/prolab_ap
sudo ./scripts/install-to-server.sh
```

### Локальная генерация (для проверки)
```bash
./scripts/gen-enterprise-variants.sh
ls -1 hostapd/generated/
```

---

## 📋 Таблица всех вариантов

### 2.4 GHz (канал 6)

| # | SSID | AKM | Cipher | PMF | Описание |
|---|------|-----|--------|-----|----------|
| 1 | `LAB-24-WPA2EAP-CCMP-PMF0` | WPA-EAP | CCMP | off | Базовый WPA2-Enterprise |
| 2 | `LAB-24-WPA2EAP-CCMP-PMF1` | WPA-EAP | CCMP | optional | WPA2-EAP с опциональным PMF |
| 3 | `LAB-24-WPA2EAP-CCMP-PMF2` | WPA-EAP | CCMP | required | WPA2-EAP с обязательным PMF |
| 4 | `LAB-24-WPA2EAPSHA256-CCMP-PMF2` | WPA-EAP-SHA256 | CCMP | required | WPA2 с SHA256 AKM |
| 5 | `LAB-24-WPA2EAP+SHA256-CCMP-PMF1` | WPA-EAP + SHA256 | CCMP | optional | Mixed AKM |
| 6 | `LAB-24-WPA2EAP-GCMP-PMF1` | WPA-EAP | GCMP | optional | GCMP cipher* |
| 7 | `LAB-24-WPA3EAP-SUITEB192-PMF2` | Suite-B-192 | GCMP-256 | required | WPA3-Enterprise 192-bit* |

### 5 GHz (канал 36)

| # | SSID | AKM | Cipher | PMF | Описание |
|---|------|-----|--------|-----|----------|
| 1 | `LAB-5G-WPA2EAP-CCMP-PMF0` | WPA-EAP | CCMP | off | Базовый WPA2-Enterprise |
| 2 | `LAB-5G-WPA2EAP-CCMP-PMF1` | WPA-EAP | CCMP | optional | WPA2-EAP с опциональным PMF |
| 3 | `LAB-5G-WPA2EAP-CCMP-PMF2` | WPA-EAP | CCMP | required | WPA2-EAP с обязательным PMF |
| 4 | `LAB-5G-WPA2EAPSHA256-CCMP-PMF2` | WPA-EAP-SHA256 | CCMP | required | WPA2 с SHA256 AKM |
| 5 | `LAB-5G-WPA2EAP+SHA256-CCMP-PMF1` | WPA-EAP + SHA256 | CCMP | optional | Mixed AKM |
| 6 | `LAB-5G-WPA2EAP-GCMP-PMF1` | WPA-EAP | GCMP | optional | GCMP cipher* |
| 7 | `LAB-5G-WPA3EAP-SUITEB192-PMF2` | Suite-B-192 | GCMP-256 | required | WPA3-Enterprise 192-bit* |

_* Может не поддерживаться некоторыми адаптерами/драйверами_

---

## 🔧 Полезные команды

### Проверка интерфейса
```bash
# Список интерфейсов
iw dev

# Режимы поддержки
iw list | grep -A 10 "Supported interface modes"

# Поддерживаемые cipher suites
iw list | grep -A 10 "Supported Cipher"
```

### Управление NetworkManager
```bash
# Отключить управление интерфейсом
sudo nmcli dev set wlx001f0566a9c0 managed no

# Проверить статус
nmcli dev status | grep wlx001f0566a9c0
```

### Сканирование
```bash
# С помощью iw
sudo iw dev wlan0 scan | grep -A 20 "LAB-"

# С помощью nmcli
nmcli dev wifi list
```

### Тест RADIUS
```bash
# Проверить подключение к RADIUS
echo "User-Name=testuser,User-Password=testpass" | \
  radclient -x 127.0.0.1:1812 auth testing123
```

---

## ⚠️ Решение проблем

### hostapd не запускается
```bash
sudo airmon-ng check kill
sudo rfkill unblock wifi
sudo nmcli dev set wlx001f0566a9c0 managed no
```

### RADIUS не отвечает
```bash
# Проверить, запущен ли
ps aux | grep freeradius

# Проверить порты
sudo netstat -tulpn | grep 1812
```

### Интерфейс занят
```bash
# Убить все процессы на интерфейсе
sudo killall hostapd wpa_supplicant
sudo ip link set wlx001f0566a9c0 down
sudo ip link set wlx001f0566a9c0 up
```

---

## 📊 Ожидаемые результаты при сканировании

При сканировании вы должны увидеть:

| SSID часть | Видно в сканере |
|------------|-----------------|
| `WPA2EAP` | WPA2-Enterprise / 802.1X |
| `EAPSHA256` | AKM: WPA-EAP-SHA256 |
| `WPA3EAP` | WPA3-Enterprise |
| `PMF0` | 802.11w disabled |
| `PMF1` | 802.11w optional/capable |
| `PMF2` | 802.11w required |
| `CCMP` | Cipher: AES-CCMP |
| `GCMP` | Cipher: GCMP (если поддерживается) |

**Важно:** EAP-метод (PEAP/TTLS/TLS) **НЕ виден** при сканировании!

---

## 📝 Быстрые заметки

- Все конфиги используют одинаковый RADIUS (127.0.0.1:1812, secret: testing123)
- FreeRADIUS должен быть запущен до hostapd
- Каждый раз перед hostapd нужно отключать управление NetworkManager
- Логи hostapd выводятся в терминал (флаг -dd)
- При ошибках проверяйте поддержку вашим адаптером нужных cipher/AKM
