# Настройка FreeRADIUS для PRO LAB

Подробное руководство по настройке FreeRADIUS для работы с Enterprise WiFi тестовой лабораторией.

---

## 📦 Установка FreeRADIUS

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y freeradius freeradius-utils
```

### CentOS/RHEL
```bash
sudo yum install -y freeradius freeradius-utils
```

### Проверка установки
```bash
freeradius -v
# Должно показать версию, например: radiusd: FreeRADIUS Version 3.0.26
```

---

## 🔧 Базовая конфигурация

### 1. Настройка клиентов (hostapd)

Файл: `/etc/freeradius/3.0/clients.conf`

```conf
# PRO LAB hostapd client
client localhost {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
    nas_type = other
    shortname = prolab-hostapd
}

# Если hostapd на другом IP
client prolab-ap {
    ipaddr = 192.168.1.100
    secret = testing123
    require_message_authenticator = no
    nas_type = other
    shortname = prolab-ap
}
```

**Важные параметры:**
- `ipaddr` — IP адрес hostapd (127.0.0.1 если на той же машине)
- `secret` — должен совпадать с `auth_server_shared_secret` в hostapd
- `require_message_authenticator` — `no` для совместимости

---

### 2. Тестовые пользователи

Файл: `/etc/freeradius/3.0/users` или `/etc/freeradius/3.0/mods-config/files/authorize`

```conf
# Простой тестовый пользователь (Cleartext)
testuser    Cleartext-Password := "testpass"
            Reply-Message := "Welcome %{User-Name}"

# Пользователь с VLAN assignment
admin       Cleartext-Password := "adminpass"
            Tunnel-Type := VLAN,
            Tunnel-Medium-Type := IEEE-802,
            Tunnel-Private-Group-Id := 100,
            Reply-Message := "Admin access granted"

# Пользователь для тестирования группового доступа
grouptest   Cleartext-Password := "grouppass"
            Reply-Message := "Group test user"

# Пользователь с ограничением по времени
timelimited Cleartext-Password := "timepass",
            Login-Time := "Al0800-1800"
```

---

### 3. Включение нужных модулей

Файл: `/etc/freeradius/3.0/mods-enabled/`

По умолчанию должны быть включены:
- `eap` — для EAP аутентификации
- `pap` — для PAP
- `chap` — для CHAP
- `mschap` — для MS-CHAP (для PEAP-MSCHAPv2)
- `files` — для файловых пользователей

Проверка:
```bash
ls -la /etc/freeradius/3.0/mods-enabled/ | grep -E 'eap|pap|chap|mschap|files'
```

---

### 4. Конфигурация EAP методов

Файл: `/etc/freeradius/3.0/mods-available/eap`

```conf
eap {
    default_eap_type = peap
    timer_expire = 60
    ignore_unknown_eap_types = no
    cisco_accounting_username_bug = no
    max_sessions = ${max_requests}

    # PEAP
    peap {
        tls = tls-common
        default_eap_type = mschapv2
        copy_request_to_tunnel = yes
        use_tunneled_reply = yes
        virtual_server = "inner-tunnel"
    }

    # TTLS
    ttls {
        tls = tls-common
        default_eap_type = mschapv2
        copy_request_to_tunnel = yes
        use_tunneled_reply = yes
        virtual_server = "inner-tunnel"
    }

    # TLS (certificate-based)
    tls {
        tls = tls-common
    }

    # Common TLS configuration
    tls-config tls-common {
        private_key_password = whatever
        private_key_file = /etc/freeradius/3.0/certs/server.key
        certificate_file = /etc/freeradius/3.0/certs/server.pem
        ca_file = /etc/freeradius/3.0/certs/ca.pem
        dh_file = /etc/freeradius/3.0/certs/dh
        cipher_list = "HIGH"
        cipher_server_preference = no
        
        # Для тестирования можно отключить проверку клиентских сертификатов
        check_cert_cn = no
    }
}
```

---

## 🔐 Сертификаты

### Генерация тестовых сертификатов

```bash
cd /etc/freeradius/3.0/certs

# Очистить старые сертификаты (если есть)
sudo rm -f *.pem *.key *.csr *.crt *.p12 *.der serial* index.txt*

# Сгенерировать новые
sudo make
```

### Параметры сертификата (опционально)

Отредактировать `/etc/freeradius/3.0/certs/ca.cnf` и `/etc/freeradius/3.0/certs/server.cnf` перед генерацией:

```ini
[certificate_authority]
countryName             = US
stateOrProvinceName     = California
localityName            = San Francisco
organizationName        = PRO LAB Test
emailAddress            = admin@prolab.test
commonName              = "PRO LAB Certificate Authority"
```

---

## ✅ Проверка конфигурации

### 1. Проверка синтаксиса
```bash
sudo freeradius -CX
```

Должно завершиться без ошибок.

### 2. Тест в debug режиме
```bash
# Остановить сервис
sudo systemctl stop freeradius

# Запустить в debug режиме
sudo freeradius -X
```

Вывод должен заканчиваться на:
```
Ready to process requests
```

### 3. Тест аутентификации
В другом терминале:

```bash
# Базовый тест
echo "User-Name=testuser,User-Password=testpass" | \
  radclient -x 127.0.0.1:1812 auth testing123

# Ожидаемый результат: Access-Accept
```

Успешный ответ:
```
Received Access-Accept Id 123 from 127.0.0.1:1812 to 127.0.0.1:43210 length 38
    Reply-Message = "Welcome testuser"
```

---

## 🚀 Запуск FreeRADIUS

### Режим отладки (для тестирования)
```bash
sudo systemctl stop freeradius
sudo freeradius -X
```

### Режим сервиса (для постоянной работы)
```bash
sudo systemctl start freeradius
sudo systemctl enable freeradius
sudo systemctl status freeradius
```

### Логи
```bash
# Просмотр логов сервиса
sudo journalctl -u freeradius -f

# Просмотр файловых логов
sudo tail -f /var/log/freeradius/radius.log
```

---

## 🧪 Тестирование с hostapd

### 1. Запустить FreeRADIUS в debug режиме
```bash
sudo freeradius -X
```

### 2. Запустить hostapd с Enterprise конфигом
```bash
/opt/prolab/scripts/ap-run.sh /opt/prolab/hostapd/generated/LAB-24-WPA2EAP-CCMP-PMF0.conf
```

### 3. Подключить клиента
На клиентском устройстве:
- SSID: `LAB-24-WPA2EAP-CCMP-PMF0`
- Security: WPA2-Enterprise
- EAP method: PEAP или TTLS
- Phase 2: MSCHAPv2
- Identity: `testuser`
- Password: `testpass`
- CA certificate: (можно игнорировать для тестов)

### 4. Проверить логи FreeRADIUS
При успешной аутентификации увидите:
```
(0) Received Access-Request Id 123 from 127.0.0.1:55123 to 127.0.0.1:1812 length 456
(0)   User-Name = "testuser"
...
(0) eap_peap: Session established
...
(0) Sent Access-Accept Id 123 from 127.0.0.1:1812 to 127.0.0.1:55123 length 234
```

---

## 🔍 Отладка

### Проблема: Access-Reject

**Причины:**
1. Неправильный пароль
2. Пользователь не найден
3. Ошибка в конфигурации EAP

**Решение:**
```bash
# Проверить наличие пользователя
sudo grep testuser /etc/freeradius/3.0/users

# Проверить EAP конфигурацию
sudo freeradius -CX | grep -A 5 eap

# Посмотреть детальные логи
sudo freeradius -X | grep -i reject
```

---

### Проблема: FreeRADIUS не отвечает

**Причины:**
1. Порты заняты
2. Firewall блокирует
3. Неправильный client secret

**Решение:**
```bash
# Проверить порты
sudo netstat -tulpn | grep 1812

# Проверить firewall
sudo ufw allow 1812/udp
sudo ufw allow 1813/udp

# Или для firewalld
sudo firewall-cmd --add-port=1812/udp --permanent
sudo firewall-cmd --add-port=1813/udp --permanent
sudo firewall-cmd --reload
```

---

### Проблема: Certificate verify failed

**Причины:**
1. Сертификаты не сгенерированы
2. Неправильные права доступа
3. Срок действия истек

**Решение:**
```bash
# Перегенерировать сертификаты
cd /etc/freeradius/3.0/certs
sudo make clean
sudo make

# Проверить права
sudo chown -R freerad:freerad /etc/freeradius/3.0/certs

# Проверить срок действия
openssl x509 -in /etc/freeradius/3.0/certs/server.pem -noout -dates
```

---

## 📊 Мониторинг

### Статистика в реальном времени
```bash
# Запросы/секунду
watch -n 1 'sudo radwho | wc -l'

# Текущие сессии
sudo radwho
```

### Счетчики
```bash
# Отправить Status-Server запрос
echo "Message-Authenticator = 0x00" | \
  radclient -x 127.0.0.1:1812 status testing123
```

---

## 🔐 Продвинутая конфигурация

### VLAN Assignment

Файл: `/etc/freeradius/3.0/users`
```conf
john    Cleartext-Password := "johnpass"
        Tunnel-Type := VLAN,
        Tunnel-Medium-Type := IEEE-802,
        Tunnel-Private-Group-Id := 10
```

### MAC-адрес аутентификация

Файл: `/etc/freeradius/3.0/mods-config/files/authorize`
```conf
# MAC address format: aa-bb-cc-dd-ee-ff
aa-bb-cc-dd-ee-ff
        Auth-Type := Accept,
        Reply-Message := "MAC authorized"
```

### SQL Backend (вместо файлов)

```bash
# Установить MySQL/PostgreSQL модуль
sudo apt install -y freeradius-mysql

# Включить SQL модуль
sudo ln -s /etc/freeradius/3.0/mods-available/sql \
           /etc/freeradius/3.0/mods-enabled/sql

# Настроить подключение в mods-available/sql
```

---

## 📝 Полезные команды

```bash
# Проверка конфигурации
sudo freeradius -CX

# Debug режим
sudo freeradius -X

# Тест клиента
echo "User-Name=testuser,User-Password=testpass" | \
  radclient -x 127.0.0.1:1812 auth testing123

# Просмотр активных сессий
sudo radwho

# Отправка Disconnect-Request
echo "User-Name=testuser" | \
  radclient -x 127.0.0.1:3799 disconnect testing123

# Логи
sudo journalctl -u freeradius -f
sudo tail -f /var/log/freeradius/radius.log
```

---

## 📚 Дополнительные ресурсы

- [FreeRADIUS Wiki](https://wiki.freeradius.org/)
- [FreeRADIUS Documentation](https://freeradius.org/documentation/)
- [EAP Types](https://en.wikipedia.org/wiki/Extensible_Authentication_Protocol)
- [802.1X Overview](https://en.wikipedia.org/wiki/IEEE_802.1X)
