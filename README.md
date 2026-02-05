# PRO LAB - Enterprise WiFi Testing

Тестовая лаборатория для Enterprise WiFi с 42 готовыми конфигурациями (WPA1/WPA2/WPA3-Enterprise, все смешанные режимы включая WPA2/WPA3 mixed).

---

## Установка на Linux

### 1. Установить зависимости

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y hostapd freeradius git
```

**Fedora/RHEL:**
```bash
sudo dnf install -y hostapd freeradius git
```

**Arch Linux:**
```bash
sudo pacman -S hostapd freeradius git
```

### 2. Скачать проект

```bash
git clone https://github.com/melvilsky/prolab_ap.git
cd prolab_ap
```

### 3. Настроить FreeRADIUS

**Добавить клиента:**
```bash
sudo tee -a /etc/freeradius/3.0/clients.conf <<EOF
client localhost {
    ipaddr = 127.0.0.1
    secret = testing123
    nas_type = other
}
EOF
```

**Добавить пользователя:**
```bash
sudo tee -a /etc/freeradius/3.0/users <<EOF
testuser    Cleartext-Password := "testpass"
EOF
```

**Проверить конфигурацию:**
```bash
sudo freeradius -CX
```

Должно завершиться без ошибок.

### 4. Узнать имя Wi-Fi интерфейса

```bash
iw dev
```

Запомните имя (например: `wlan0`, `wlp3s0`, `wlx001f0566a9c0`).

---

## Запуск

### Терминал 1: FreeRADIUS

```bash
sudo systemctl stop freeradius  # если запущен как сервис
sudo freeradius -X
```

Дождитесь: `Ready to process requests`

### Терминал 2: PRO LAB

```bash
export WIFI_IFACE=wlan0  # замените на ваш интерфейс
./lab.sh
```

В меню:
- Нажмите `1` (Запустить AP)
- Выберите конфиг (рекомендую `2`)
- Нажмите `Enter`

AP запущен!

---

## Подключение клиента

**На телефоне/ноутбуке:**

Найдите сеть: `LAB-24-WPA2Ent-CCMP-P1` (или другую)

**Настройки:**
- Security: WPA2-Enterprise
- EAP method: PEAP
- Phase 2: MSCHAPv2
- CA certificate: (не проверять)
- Username: `testuser`
- Password: `testpass`

Подключитесь.

---

## Остановка

В терминале с hostapd: `Ctrl+C`

---

## Автотест всех конфигов

```bash
# Терминал 1: FreeRADIUS запущен
# Терминал 2:
./scripts/test-all-configs.sh 20
```

Каждый конфиг запустится на 20 секунд. Логи в `logs/`.

---

## Конфигурации

**42 конфига** (21 для 2.4GHz + 21 для 5GHz)

### WPA2-Enterprise (базовые)
- `WPA2Ent-CCMP-P0` - CCMP, PMF off (legacy)
- `WPA2Ent-CCMP-P1` - CCMP, PMF optional (**рекомендуется**)
- `WPA2Ent-CCMP-P2` - CCMP, PMF required
- `WPA2Ent-CCMP-P0-Leg` - без 802.11n (старые устройства)

### WPA2-Enterprise SHA256
- `WPA2Ent-SHA256-CCMP-P1` - SHA256, CCMP, PMF optional
- `WPA2Ent-SHA256-CCMP-P2` - SHA256, CCMP, PMF required
- `WPA2Ent-SHA256-GCMP-P2` - SHA256, GCMP, PMF required

### WPA2-Enterprise Mixed AKM
- `WPA2Ent-Mix-CCMP-P1` - оба AKM (WPA-EAP + SHA256), PMF optional
- `WPA2Ent-Mix-CCMP-P2` - оба AKM, PMF required

### WPA2-Enterprise GCMP
- `WPA2Ent-GCMP-P1` - GCMP, PMF optional
- `WPA2Ent-GCMP-P2` - GCMP, PMF required
- `WPA2Ent-CCMP-GCMP-P1` - оба cipher, PMF optional

### WPA3-Enterprise
- `WPA3Ent-192b-P2` - Suite-B 192-bit, GCMP-256

### WPA2-WPA3-Enterprise mixed
- `WPA2WPA3-CCMP-G256-P2` - WPA-EAP + Suite-B-192
- `W2SHA-W3-CG256-P2` - SHA256 + Suite-B-192
- `W2W3-ALL-CG256-P2` - все 3 AKM (WPA-EAP + SHA256 + Suite-B)

### WPA-Enterprise (legacy WPA1)
- `WPA1Ent-TKIP-P0` - только WPA1, TKIP

### WPA-WPA2-Enterprise (mixed mode)
- `WPA-WPA2Ent-TKIP-P0` - TKIP только, PMF off
- `WPA-WPA2Ent-TKIP-CCMP-P0` - TKIP+CCMP, PMF off
- `WPA-WPA2Ent-TKIP-CCMP-P1` - TKIP+CCMP, PMF optional
- `WPA-WPA2Ent-CCMP-P0` - CCMP только, PMF off

**Расшифровка:**
- `WPA2Ent` = WPA2-Enterprise
- `WPA3Ent` = WPA3-Enterprise
- `Mix` = Mixed AKM
- `P0/P1/P2` = PMF off/optional/required
- `G256` = GCMP-256
- `Leg` = Legacy

_Каждый вариант доступен для 2.4GHz (24) и 5GHz (5G)_

---

## Меню lab.sh

```
1) Запустить AP          - Выбор и запуск конфига
2) Показать конфиги      - Список всех вариантов
3) Генерация конфигов    - Перегенерация
4) Проверка системы      - Диагностика
5) Автотест              - Прогон всех по очереди
6) Настройки             - Изменить Wi-Fi интерфейс
q) Выход
```

**Номера профилей фиксированы.** При генерации создается `hostapd/generated/index.tsv`,
и меню читает номера из него. После `gen-enterprise-variants.sh` номера всегда
соответствуют одному и тому же SSID.

---

## Команды напрямую

```bash
# Запуск конкретного конфига
./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2Ent-CCMP-P1.conf

# Проверка системы
./scripts/check-system.sh

# Автотест (30 сек каждый)
./scripts/test-all-configs.sh 30

# Генерация конфигов заново
./scripts/gen-enterprise-variants.sh
```

---

## Настройка

### Изменить Wi-Fi интерфейс

```bash
export WIFI_IFACE=wlan0
./lab.sh
```

Или в меню: `6` → `1`

### Изменить канал

Отредактировать `scripts/gen-enterprise-variants.sh`:
```bash
CH_24="1"   # для 2.4 GHz (1, 6, 11)
CH_5="149"  # для 5 GHz (36, 40, 149, 153)
```

Перегенерировать: `./scripts/gen-enterprise-variants.sh`

---

## Решение проблем

### hostapd не запускается

```bash
sudo nmcli dev set wlan0 managed no
sudo killall hostapd wpa_supplicant
sudo rfkill unblock wifi
```

### FreeRADIUS не отвечает

```bash
# Проверка
ps aux | grep freeradius

# Тест
echo "User-Name=testuser,User-Password=testpass" | \
  radclient -x 127.0.0.1:1812 auth testing123
```

Должно быть: `Access-Accept`

### NetworkManager перехватывает интерфейс

**Постоянное отключение:**
```bash
sudo tee /etc/NetworkManager/conf.d/unmanaged-wifi.conf <<EOF
[keyfile]
unmanaged-devices=interface-name:wlan0
EOF

sudo systemctl restart NetworkManager
```

### Некоторые конфиги не работают

GCMP и Suite-B поддерживаются не всеми адаптерами.

Проверить:
```bash
iw list | grep -A 10 "Supported Cipher"
```

### Operation not permitted

```bash
sudo systemctl stop NetworkManager
# или
sudo nmcli dev set wlan0 managed no
```

### Could not configure driver mode

Проверить поддержку AP режима:
```bash
iw list | grep -A 10 "Supported interface modes"
```

Должно быть: `* AP`

---

## Полезные команды

```bash
# Информация об интерфейсе
iw dev wlan0 info

# Подключенные клиенты
sudo iw dev wlan0 station dump

# Сканирование WiFi (с другого интерфейса)
sudo iw dev wlan1 scan | grep -A 20 "LAB-"

# Логи FreeRADIUS
sudo journalctl -u freeradius -f

# Порты RADIUS
sudo netstat -tulpn | grep 1812
```

---

## Структура проекта

```
prolab_ap/
├── lab.sh                      - Главный скрипт с меню
├── README.md                   - Этот файл
├── hostapd/
│   ├── common/radius.conf      - Шаблон RADIUS (справочно)
│   ├── generated/              - 42 готовых конфига (автономных)
│   │   └── index.tsv            - фиксированные номера профилей
│   └── custom/                 - Ваши ручные конфиги
└── scripts/
    ├── ap-run.sh               - Запуск AP
    ├── gen-enterprise-variants.sh - Генератор
    ├── test-all-configs.sh     - Автотест всех конфигов
    ├── check-system.sh         - Диагностика системы
    ├── install-to-server.sh    - Установка на сервер
    └── clean-generated.sh      - Очистка конфигов
```

**Примечание:** Конфиги в `generated/` автономны - RADIUS настройки встроены в каждый файл.
`common/radius.conf` используется только как справочный шаблон.

---

## Параметры безопасности

### AKM (Authentication Key Management)
- **WPA-EAP** - стандартный Enterprise
- **WPA-EAP-SHA256** - с SHA256 (усиленный)
- **Mixed** - оба одновременно
- **Suite-B-192** - WPA3-Enterprise 192-bit

### PMF (Protected Management Frames)
- **0 (disabled)** - для старых устройств
- **1 (optional)** - рекомендуется (совместимость)
- **2 (required)** - только современные

### Cipher Suites
- **CCMP** - стандартный AES (везде)
- **GCMP** - быстрее на 802.11ac/ax
- **GCMP-256** - для Suite-B

---

## Совместимость устройств

| Устройство | WPA2-EAP | PMF | SHA256 | GCMP |
|------------|----------|-----|--------|------|
| Windows 10/11 | ✅ | ✅ | ✅ | ✅ |
| macOS 10.13+ | ✅ | ✅ | ✅ | ✅ |
| Linux | ✅ | ✅ | ✅ | ✅ |
| iOS 8+ | ✅ | ✅ | ✅ | ⚠️ |
| Android 6+ | ✅ | ✅ | ✅ | ⚠️ |
| IoT | ✅ | ❌ | ❌ | ❌ |

✅ Полная | ⚠️ Частичная | ❌ Нет

---

## Ручные конфиги

Создавайте свои `.conf` файлы в `hostapd/custom/`:

```bash
nano hostapd/custom/my-network.conf
```

Пример:
```conf
interface=wlan0
driver=nl80211
ssid=MyTestNetwork
hw_mode=g
channel=6
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=CCMP
ieee80211w=1

# RADIUS configuration
auth_server_addr=127.0.0.1
auth_server_port=1812
auth_server_shared_secret=testing123

acct_server_addr=127.0.0.1
acct_server_port=1813
acct_server_shared_secret=testing123

own_ip_addr=127.0.0.1

ieee8021x=1
eapol_version=2
auth_algs=1
```

Запуск:
```bash
./scripts/ap-run.sh hostapd/custom/my-network.conf
```

---

## Дополнительно

### VLAN Assignment

Файл: `/etc/freeradius/3.0/users`
```conf
admin    Cleartext-Password := "adminpass"
         Tunnel-Type := VLAN,
         Tunnel-Medium-Type := IEEE-802,
         Tunnel-Private-Group-Id := 100
```

### Логирование

```bash
# Логи hostapd с сохранением
./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2Ent-CCMP-P1.conf 2>&1 | tee hostapd.log
```

### Изменение RADIUS настроек

Для ручных конфигов:
```bash
nano hostapd/custom/my-network.conf
# Изменить секцию # RADIUS configuration
```

Для автогенерируемых конфигов:
```bash
nano scripts/gen-enterprise-variants.sh
# Изменить секцию "# RADIUS configuration (embedded)" в функции write_cfg()
./scripts/gen-enterprise-variants.sh  # перегенерировать
```

---

## Лицензия

MIT License

---

**Начните с:** `./lab.sh` 🚀
