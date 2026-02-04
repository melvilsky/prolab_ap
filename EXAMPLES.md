# Примеры использования PRO LAB

Практические примеры и сценарии использования тестовой лаборатории Enterprise WiFi.

---

## 🎯 Сценарий 1: Быстрый старт (первый запуск)

### Шаг 1: Проверка системы
```bash
./scripts/check-system.sh
```

Скрипт проверит:
- ✅ Установлено ли необходимое ПО
- ✅ Доступен ли Wi-Fi интерфейс
- ✅ Запущен ли FreeRADIUS
- ✅ Сгенерированы ли конфиги

### Шаг 2: Генерация конфигов (если не сгенерированы)
```bash
./scripts/gen-enterprise-variants.sh
```

### Шаг 3: Запуск FreeRADIUS (терминал 1)
```bash
sudo systemctl stop freeradius  # Остановить сервис
sudo freeradius -X              # Запустить в debug режиме
```

### Шаг 4: Запуск первого AP (терминал 2)
```bash
./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF0.conf
```

### Шаг 5: Подключение клиента
На телефоне/ноутбуке:
- **SSID:** `LAB-24-WPA2EAP-CCMP-PMF0`
- **Security:** WPA2-Enterprise
- **EAP method:** PEAP
- **Phase 2:** MSCHAPv2
- **Identity:** `testuser`
- **Password:** `testpass`

---

## 🔬 Сценарий 2: Тестирование совместимости со старым устройством

Проверить, поддерживает ли устройство PMF (Protected Management Frames).

### Тест 1: PMF disabled
```bash
./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF0.conf
```
**Ожидание:** Старые устройства **должны** подключиться

### Тест 2: PMF optional
```bash
./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF1.conf
```
**Ожидание:** И старые, и новые устройства **должны** подключиться

### Тест 3: PMF required
```bash
./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF2.conf
```
**Ожидание:** Старые устройства (до 2013 года) **не смогут** подключиться

---

## 🚀 Сценарий 3: Автоматический прогон всех конфигов

Запустить все 14 конфигураций по очереди, каждую на 30 секунд:

```bash
# В терминале 1: FreeRADIUS
sudo freeradius -X

# В терминале 2: автоматическое тестирование
./scripts/test-all-configs.sh 30
```

Логи будут сохранены в `logs/` директории.

Посмотреть результаты:
```bash
ls -lt logs/
less logs/LAB-24-WPA2EAP-CCMP-PMF0_20260204_153045.log
```

---

## 🔍 Сценарий 4: Сканирование и проверка параметров безопасности

### На Linux
```bash
# Сканирование всех сетей
sudo iw dev wlan0 scan | grep -A 30 "LAB-"

# Детальная информация о конкретной сети
sudo iw dev wlan0 scan | grep -A 30 "LAB-24-WPA2EAP-CCMP-PMF2"
```

### С помощью NetworkManager
```bash
nmcli dev wifi list
nmcli dev wifi list | grep LAB
```

### С помощью Python (детальный парсинг)
```python
import subprocess
import re

def scan_wifi():
    result = subprocess.run(['sudo', 'iw', 'dev', 'wlan0', 'scan'], 
                          capture_output=True, text=True)
    
    networks = []
    current = {}
    
    for line in result.stdout.split('\n'):
        if 'SSID:' in line:
            if current:
                networks.append(current)
            current = {'ssid': line.split('SSID:')[1].strip()}
        elif 'WPA' in line and 'Version' in line:
            current['wpa_version'] = line.strip()
        elif 'Authentication suites' in line:
            current['auth'] = line.strip()
        elif 'RSN:' in line:
            current['rsn'] = True
    
    if current:
        networks.append(current)
    
    # Показать только LAB сети
    for net in networks:
        if net.get('ssid', '').startswith('LAB-'):
            print(f"\n{net['ssid']}:")
            for k, v in net.items():
                if k != 'ssid':
                    print(f"  {k}: {v}")

scan_wifi()
```

---

## 🏢 Сценарий 5: Тестирование корпоративной конфигурации

Проверить конфигурацию, рекомендованную для корпоративных сетей.

### 2.4 GHz (для совместимости)
```bash
./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF1.conf
```

### 5 GHz (для производительности)
```bash
./scripts/ap-run.sh hostapd/generated/LAB-5G-WPA2EAP-CCMP-PMF1.conf
```

**Параметры:**
- ✅ WPA2-Enterprise (широкая совместимость)
- ✅ PMF optional (поддержка как старых, так и новых устройств)
- ✅ CCMP cipher (стандартный, поддерживается везде)

---

## 🔐 Сценарий 6: Тестирование максимальной безопасности

Для критических сетей с повышенными требованиями:

### SHA256 AKM
```bash
./scripts/ap-run.sh hostapd/generated/LAB-5G-WPA2EAPSHA256-CCMP-PMF2.conf
```

### WPA3-Enterprise (если поддерживается)
```bash
./scripts/ap-run.sh hostapd/generated/LAB-5G-WPA3EAP-SUITEB192-PMF2.conf
```

**Примечание:** Suite-B может не работать на всех адаптерах.

---

## 📊 Сценарий 7: Сравнение производительности CCMP vs GCMP

### Запустить с CCMP
```bash
./scripts/ap-run.sh hostapd/generated/LAB-5G-WPA2EAP-CCMP-PMF1.conf
```

Измерить throughput:
```bash
# На клиенте
iperf3 -c <server_ip> -t 60
```

### Запустить с GCMP (если поддерживается)
```bash
./scripts/ap-run.sh hostapd/generated/LAB-5G-WPA2EAP-GCMP-PMF1.conf
```

Измерить throughput:
```bash
iperf3 -c <server_ip> -t 60
```

Сравнить результаты. GCMP теоретически должен быть быстрее на 802.11ac/ax.

---

## 🔧 Сценарий 8: Отладка проблем подключения

### Проблема: Клиент не может подключиться

#### Шаг 1: Проверить, что сеть видна
```bash
sudo iw dev wlan0 scan | grep "LAB-24"
```

#### Шаг 2: Проверить логи FreeRADIUS
В терминале с `sudo freeradius -X` найти:
```
(0) Received Access-Request Id 123 from 127.0.0.1:55123
(0)   User-Name = "testuser"
```

Если не видно - проблема в hostapd или сетевом подключении.

#### Шаг 3: Проверить логи hostapd
Искать строки:
```
wlan0: STA aa:bb:cc:dd:ee:ff IEEE 802.11: authenticated
wlan0: STA aa:bb:cc:dd:ee:ff IEEE 802.11: associated
```

#### Шаг 4: Тест подключения к RADIUS вручную
```bash
echo "User-Name=testuser,User-Password=testpass" | \
  radclient -x 127.0.0.1:1812 auth testing123
```

Ожидание: `Access-Accept`

---

## 🎓 Сценарий 9: Обучение - демонстрация разных параметров

### Демо 1: Влияние PMF

Запускать по очереди:
```bash
# 1. PMF off
./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF0.conf

# 2. PMF optional
./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF1.conf

# 3. PMF required
./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF2.conf
```

На каждом этапе сканировать и показывать разницу в capabilities.

### Демо 2: Mixed AKM

Показать, что одна сеть поддерживает оба AKM:
```bash
./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2EAP+SHA256-CCMP-PMF1.conf
```

При сканировании будет видно оба метода аутентификации.

---

## 🌐 Сценарий 10: Тестирование на разных каналах

### Изменить канал 2.4 GHz

Отредактировать `scripts/gen-enterprise-variants.sh`:
```bash
CH_24="1"   # вместо 6
```

Перегенерировать:
```bash
./scripts/clean-generated.sh
./scripts/gen-enterprise-variants.sh
```

### Изменить канал 5 GHz

```bash
CH_5="149"  # вместо 36 (для DFS-free)
```

**Популярные каналы:**
- **2.4 GHz:** 1, 6, 11 (не перекрываются)
- **5 GHz:** 36, 40, 44, 48 (нижний диапазон)
- **5 GHz:** 149, 153, 157, 161 (верхний диапазон, обычно без DFS)

---

## 💾 Сценарий 11: Сохранение логов для анализа

### Сохранить лог одного теста
```bash
mkdir -p logs
./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF0.conf 2>&1 | \
  tee logs/test_$(date +%Y%m%d_%H%M%S).log
```

### Автоматическое сохранение для всех тестов
```bash
./scripts/test-all-configs.sh 30
# Логи автоматически сохраняются в logs/
```

### Анализ логов
```bash
# Найти ошибки
grep -i "error" logs/*.log

# Найти успешные подключения
grep -i "associated" logs/*.log

# Найти конкретного клиента
grep "aa:bb:cc:dd:ee:ff" logs/*.log
```

---

## 🔄 Сценарий 12: Переход с одного конфига на другой без остановки RADIUS

```bash
# Терминал 1: FreeRADIUS (запускается один раз)
sudo freeradius -X

# Терминал 2: последовательная смена конфигов
./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF0.conf
# Ctrl+C

./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF1.conf
# Ctrl+C

./scripts/ap-run.sh hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF2.conf
# Ctrl+C
```

FreeRADIUS продолжает работать между сменами конфигов.

---

## 📱 Сценарий 13: Тестирование с мобильными устройствами

### iOS (iPhone/iPad)
1. Settings → Wi-Fi
2. Выбрать сеть `LAB-24-WPA2EAP-CCMP-PMF1`
3. Username: `testuser`
4. Password: `testpass`
5. При запросе сертификата - Trust

### Android
1. Settings → Wi-Fi
2. Выбрать сеть
3. EAP method: PEAP
4. Phase 2: MSCHAPv2
5. Identity: `testuser`
6. Password: `testpass`
7. Anonymous identity: (пусто)

### Windows 10/11
1. Network settings → Add network
2. SSID: `LAB-24-WPA2EAP-CCMP-PMF1`
3. Security: WPA2-Enterprise
4. Authentication: PEAP
5. Username: `testuser`
6. Password: `testpass`

---

## 🧪 Полезные команды для тестирования

```bash
# Проверка текущего канала AP
sudo iw dev wlx001f0566a9c0 info | grep channel

# Мониторинг подключенных клиентов
watch -n 1 'sudo iw dev wlx001f0566a9c0 station dump'

# Просмотр статистики hostapd
sudo hostapd_cli status

# Отключить конкретного клиента
sudo hostapd_cli deauthenticate aa:bb:cc:dd:ee:ff

# Список всех активных RADIUS сессий
sudo radwho
```

---

## 📚 Дополнительные ресурсы

- Полная документация: `README.md`
- Детальная матрица конфигов: `CONFIGS_MATRIX.md`
- Быстрый старт: `QUICKSTART.md`
- Развертывание на сервере: `DEPLOYMENT.md`
- Настройка FreeRADIUS: `docs/RADIUS_SETUP.md`
