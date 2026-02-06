#!/usr/bin/env bash
# Скрипт для проверки готовности системы к работе

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Счетчики
ERRORS=0
WARNINGS=0
SUCCESS=0

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}PRO LAB: Проверка системы${NC}"
echo -e "${BLUE}=================================${NC}"
echo

# Функция проверки
check() {
    local name="$1"
    local command="$2"
    local required="$3"
    
    printf "%-40s" "$name"
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        ((SUCCESS++))
        return 0
    else
        if [ "$required" = "required" ]; then
            echo -e "${RED}✗ ОШИБКА${NC}"
            ((ERRORS++))
        else
            echo -e "${YELLOW}⚠ ПРЕДУПРЕЖДЕНИЕ${NC}"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Проверка команд
echo -e "${BLUE}=== Проверка установленных программ ===${NC}"
check "hostapd" "which hostapd" "required"
check "freeradius" "which freeradius" "required"
check "nmcli (NetworkManager)" "which nmcli" "optional"
check "iw" "which iw" "required"
check "ip" "which ip" "required"
check "radclient" "which radclient" "required"
echo

# Проверка Wi-Fi интерфейса
echo -e "${BLUE}=== Проверка Wi-Fi интерфейса ===${NC}"
IFACE="${IFACE:-wlx001f0566a9c0}"

if ip link show "$IFACE" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Интерфейс $IFACE существует${NC}"
    ((SUCCESS++))
    
    # Проверка поддержки AP режима
    if iw list 2>/dev/null | grep -q "* AP"; then
        echo -e "${GREEN}✓ Режим AP поддерживается${NC}"
        ((SUCCESS++))
    else
        echo -e "${RED}✗ Режим AP НЕ поддерживается${NC}"
        ((ERRORS++))
    fi
    
    # Проверка состояния интерфейса
    if ip link show "$IFACE" | grep -q "UP"; then
        echo -e "${GREEN}✓ Интерфейс включен (UP)${NC}"
        ((SUCCESS++))
    else
        echo -e "${YELLOW}⚠ Интерфейс выключен (DOWN)${NC}"
        echo "  Включите: sudo ip link set $IFACE up"
        ((WARNINGS++))
    fi
    
    # Проверка управления NetworkManager
    if which nmcli >/dev/null 2>&1; then
        if nmcli dev status | grep "$IFACE" | grep -q "unmanaged"; then
            echo -e "${GREEN}✓ NetworkManager не управляет интерфейсом${NC}"
            ((SUCCESS++))
        else
            echo -e "${YELLOW}⚠ NetworkManager управляет интерфейсом${NC}"
            echo "  Отключите: sudo nmcli dev set $IFACE managed no"
            ((WARNINGS++))
        fi
    fi
else
    echo -e "${RED}✗ Интерфейс $IFACE не найден${NC}"
    echo "  Доступные интерфейсы:"
    iw dev 2>/dev/null | grep Interface | awk '{print "    " $2}'
    ((ERRORS++))
fi
echo

# Проверка FreeRADIUS
echo -e "${BLUE}=== Проверка FreeRADIUS ===${NC}"

if pgrep -x "freeradius" >/dev/null; then
    echo -e "${GREEN}✓ FreeRADIUS запущен${NC}"
    ((SUCCESS++))
else
    echo -e "${YELLOW}⚠ FreeRADIUS не запущен${NC}"
    echo "  Запустите: sudo freeradius -X"
    ((WARNINGS++))
fi

# Проверка портов RADIUS
if sudo netstat -tulpn 2>/dev/null | grep -q ":1812"; then
    echo -e "${GREEN}✓ Порт 1812 (auth) слушается${NC}"
    ((SUCCESS++))
else
    echo -e "${RED}✗ Порт 1812 не слушается${NC}"
    ((ERRORS++))
fi

if sudo netstat -tulpn 2>/dev/null | grep -q ":1813"; then
    echo -e "${GREEN}✓ Порт 1813 (acct) слушается${NC}"
    ((SUCCESS++))
else
    echo -e "${YELLOW}⚠ Порт 1813 не слушается${NC}"
    ((WARNINGS++))
fi

# Проверка конфигурации FreeRADIUS
if [ -f /etc/freeradius/3.0/clients.conf ]; then
    if grep -q "testing123" /etc/freeradius/3.0/clients.conf 2>/dev/null; then
        echo -e "${GREEN}✓ Client secret найден в конфигурации${NC}"
        ((SUCCESS++))
    else
        echo -e "${YELLOW}⚠ Client secret 'testing123' не найден${NC}"
        ((WARNINGS++))
    fi
fi

# Тест подключения к RADIUS
if which radclient >/dev/null 2>&1 && pgrep -x "freeradius" >/dev/null; then
    if echo "User-Name=testuser,User-Password=testpass" | \
       timeout 2 radclient -x 127.0.0.1:1812 auth testing123 2>&1 | grep -q "Access-"; then
        echo -e "${GREEN}✓ RADIUS отвечает на запросы${NC}"
        ((SUCCESS++))
    else
        echo -e "${YELLOW}⚠ RADIUS не отвечает или тестовый пользователь не настроен${NC}"
        ((WARNINGS++))
    fi
fi
echo

# Проверка структуры проекта
echo -e "${BLUE}=== Проверка структуры проекта ===${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

check "Директория hostapd/common" "[ -d '$PROJECT_ROOT/hostapd/common' ]" "required"
check "Файл radius.conf" "[ -f '$PROJECT_ROOT/hostapd/common/radius.conf' ]" "required"
check "Директория hostapd/generated" "[ -d '$PROJECT_ROOT/hostapd/generated' ]" "required"
check "Директория scripts" "[ -d '$PROJECT_ROOT/scripts' ]" "required"

# Проверка наличия конфигов
CONFIGS_COUNT=$(ls -1 "$PROJECT_ROOT/hostapd/generated/"*.conf 2>/dev/null | wc -l | tr -d ' ')
if [ "$CONFIGS_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Найдено конфигов: $CONFIGS_COUNT${NC}"
    ((SUCCESS++))
else
    echo -e "${YELLOW}⚠ Конфиги не сгенерированы${NC}"
    echo "  Запустите: $PROJECT_ROOT/scripts/gen-enterprise-variants.sh"
    ((WARNINGS++))
fi
echo

# Проверка прав на выполнение скриптов
echo -e "${BLUE}=== Проверка прав скриптов ===${NC}"
for script in "$PROJECT_ROOT/scripts/"*.sh; do
    if [ -x "$script" ]; then
        echo -e "${GREEN}✓ $(basename "$script")${NC}"
        ((SUCCESS++))
    else
        echo -e "${YELLOW}⚠ $(basename "$script") - нет прав на выполнение${NC}"
        echo "  Исправить: chmod +x $script"
        ((WARNINGS++))
    fi
done
echo

# Проверка возможностей адаптера (iw list может выводить 2412.0 MHz / CCMP-128)
echo -e "${BLUE}=== Проверка возможностей Wi-Fi адаптера ===${NC}"

IW_LIST=""
[ -n "$IFACE" ] && IW_LIST=$(iw list 2>/dev/null) || true

if echo "$IW_LIST" | grep -qE "2412(\.0)? MHz"; then
    echo -e "${GREEN}✓ Поддержка 2.4 GHz${NC}"
    ((SUCCESS++))
else
    echo -e "${RED}✗ 2.4 GHz не поддерживается${NC}"
    ((ERRORS++))
fi

if echo "$IW_LIST" | grep -qE "5180(\.0)? MHz"; then
    echo -e "${GREEN}✓ Поддержка 5 GHz${NC}"
    ((SUCCESS++))
else
    echo -e "${YELLOW}⚠ 5 GHz не поддерживается${NC}"
    ((WARNINGS++))
fi

# Секция "Supported Ciphers:" выводит CCMP-128, GCMP-128, GCMP-256
CIPHERS_SECTION=$(echo "$IW_LIST" | sed -n '/Supported Ciphers:/,/^[[:space:]]*$/p' | head -20)
if echo "$CIPHERS_SECTION" | grep -q "CCMP-"; then
    echo -e "${GREEN}✓ CCMP cipher поддерживается${NC}"
    ((SUCCESS++))
else
    echo -e "${RED}✗ CCMP cipher не поддерживается${NC}"
    ((ERRORS++))
fi

if echo "$CIPHERS_SECTION" | grep -q "GCMP-"; then
    echo -e "${GREEN}✓ GCMP cipher поддерживается${NC}"
    ((SUCCESS++))
else
    echo -e "${YELLOW}⚠ GCMP cipher не поддерживается (некоторые конфиги не будут работать)${NC}"
    ((WARNINGS++))
fi
echo

# Итоговый отчет
echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}ИТОГОВЫЙ ОТЧЕТ${NC}"
echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}Успешно: $SUCCESS${NC}"
echo -e "${YELLOW}Предупреждения: $WARNINGS${NC}"
echo -e "${RED}Ошибки: $ERRORS${NC}"
echo

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Система готова к работе!${NC}"
    echo
    echo "Для запуска тестов:"
    echo "  1. Терминал 1: sudo freeradius -X"
    echo "  2. Терминал 2: $PROJECT_ROOT/scripts/ap-run.sh <конфиг>"
    echo
    echo "Или автоматический прогон всех конфигов:"
    echo "  $PROJECT_ROOT/scripts/test-all-configs.sh 30"
    exit 0
else
    echo -e "${RED}✗ Обнаружены критические ошибки!${NC}"
    echo "Исправьте ошибки перед запуском тестов."
    exit 1
fi
