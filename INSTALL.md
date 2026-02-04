# ⚡ Установка за 3 минуты

## На локальной машине (для разработки)

```bash
# 1. Клонировать
git clone <ваш-repo-url> prolab_ap
cd prolab_ap

# 2. Запустить
./lab.sh
```

**Готово!** Конфиги уже в Git, ничего генерировать не нужно.

---

## На сервере (для продакшен)

### Способ 1: Через Git (рекомендуется)

```bash
# 1. Установить зависимости
sudo apt update && sudo apt install -y hostapd freeradius git

# 2. Клонировать
cd /opt
sudo git clone <ваш-repo-url> prolab

# 3. Настроить FreeRADIUS
sudo nano /etc/freeradius/3.0/clients.conf
# Добавить:
#   client localhost {
#       ipaddr = 127.0.0.1
#       secret = testing123
#       nas_type = other
#   }

sudo nano /etc/freeradius/3.0/users
# Добавить:
#   testuser    Cleartext-Password := "testpass"

# 4. Запустить
cd /opt/prolab
./lab.sh
```

### Способ 2: Автоматическая установка

```bash
# 1. Склонировать в /tmp
cd /tmp
git clone <ваш-repo-url> prolab_ap
cd prolab_ap

# 2. Запустить установку (создаст /opt/prolab)
sudo ./scripts/install-to-server.sh

# 3. Использовать
cd /opt/prolab
./lab.sh
```

---

## ✅ Проверка установки

```bash
# Проверить систему
./scripts/check-system.sh

# Или через меню
./lab.sh  # опция 4
```

---

## 🎯 Первый запуск

### Терминал 1:
```bash
sudo freeradius -X
```

### Терминал 2:
```bash
./lab.sh
# Выбрать: 1 → 2 (WPA2EAP-CCMP-PMF1)
```

### На клиенте:
- SSID: LAB-24-WPA2EAP-CCMP-PMF1
- User: testuser
- Pass: testpass

**Работает!** 🎉
