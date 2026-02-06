#!/usr/bin/env bash
# Полуавтоматический тест: переход к следующему по Enter
set -e

CONFIGS_DIR="${CONFIGS_DIR:-$(dirname "$0")/../hostapd/generated}"
DURATION="${1:-30}"  # Время работы каждой конфигурации в секундах
LOG_DIR="${LOG_DIR:-$(dirname "$0")/../logs}"
IFACE="${WIFI_IFACE:-wlx001f0566a9c0}"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}PRO LAB: Полуавтоматический тест${NC}"
echo -e "${BLUE}=================================${NC}"
echo
echo "Директория конфигов: $CONFIGS_DIR"
echo "Длительность теста каждого конфига: ${DURATION}s"
echo "Логи будут сохранены в: $LOG_DIR"
echo "Интерфейс: $IFACE"
echo

# Создать директорию для логов
mkdir -p "$LOG_DIR"

# Проверить наличие конфигов
if [ ! -d "$CONFIGS_DIR" ] || [ -z "$(ls -A "$CONFIGS_DIR"/*.conf 2>/dev/null)" ]; then
    echo -e "${RED}Ошибка: Конфиги не найдены в $CONFIGS_DIR${NC}"
    echo "Запустите сначала: ./scripts/gen-enterprise-variants.sh"
    exit 1
fi

# Проверить, запущен ли FreeRADIUS
if ! pgrep -x "freeradius" > /dev/null; then
    echo -e "${YELLOW}Внимание: FreeRADIUS не запущен!${NC}"
    echo "Запустите в отдельном терминале: sudo freeradius -X"
    echo
    read -p "Продолжить? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Сформировать список конфигов (стабильный порядок)
CONFIG_LIST=()
INDEX_FILE="$CONFIGS_DIR/index.tsv"
if [ -f "$INDEX_FILE" ]; then
    while IFS=$'\t' read -r _ profile _; do
        [ -n "$profile" ] && CONFIG_LIST+=("$CONFIGS_DIR/$profile")
    done < "$INDEX_FILE"
else
    while IFS= read -r conf; do
        CONFIG_LIST+=("$conf")
    done < <(ls -1 "$CONFIGS_DIR"/*.conf)
fi

TOTAL_CONFIGS="${#CONFIG_LIST[@]}"
echo -e "${GREEN}Найдено конфигов: $TOTAL_CONFIGS${NC}"
echo

# Функция для запуска одного конфига
test_config() {
    local conf="$1"
    local index="$2"
    local total="$3"
    local basename=$(basename "$conf" .conf)
    local ssid=$(grep "^ssid=" "$conf" | cut -d= -f2)
    local logfile="$LOG_DIR/${basename}_$(date +%Y%m%d_%H%M%S).log"
    
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}[$index/$total] Профиль: $basename${NC}"
    echo -e "${BLUE}SSID: $ssid${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo "Конфиг: $conf"
    echo "Лог: $logfile"
    echo
    
    # Отключить управление NetworkManager
    sudo nmcli dev set "$IFACE" managed no >/dev/null 2>&1 || true
    
    # Запустить AP с таймаутом
    echo -e "${GREEN}Запуск AP (${DURATION}s)...${NC}"
    timeout ${DURATION}s sudo hostapd -dd "$conf" > "$logfile" 2>&1 || {
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            echo -e "${GREEN}✓ Тест завершен (timeout)${NC}"
        else
            echo -e "${RED}✗ Ошибка запуска (код: $exit_code)${NC}"
            echo "Смотрите лог: $logfile"
        fi
    }
    echo
}

# Основной цикл
index=1
for conf in "${CONFIG_LIST[@]}"; do
    read -p "Нажмите Enter для запуска следующего профиля (или q для выхода): " -r answer
    if [ "$answer" = "q" ] || [ "$answer" = "Q" ]; then
        echo -e "${YELLOW}Остановлено пользователем.${NC}"
        break
    fi
    test_config "$conf" "$index" "$TOTAL_CONFIGS"
    ((index++))
done

echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}✓ Полуавтоматический тест завершен!${NC}"
echo -e "${BLUE}=================================${NC}"
echo
echo "Логи сохранены в: $LOG_DIR"
echo "Для просмотра логов:"
echo "  ls -lt $LOG_DIR"
echo "  less $LOG_DIR/<имя_файла>.log"
