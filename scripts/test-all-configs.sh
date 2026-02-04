#!/usr/bin/env bash
# Скрипт для последовательного тестирования всех конфигураций
set -e

CONFIGS_DIR="${CONFIGS_DIR:-$(dirname "$0")/../hostapd/generated}"
DURATION="${1:-30}"  # Время работы каждой конфигурации в секундах
LOG_DIR="${LOG_DIR:-$(dirname "$0")/../logs}"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=================================${NC}"
echo -e "${BLUE}PRO LAB: Тест всех конфигураций${NC}"
echo -e "${BLUE}=================================${NC}"
echo
echo "Директория конфигов: $CONFIGS_DIR"
echo "Длительность теста каждого конфига: ${DURATION}s"
echo "Логи будут сохранены в: $LOG_DIR"
echo

# Создать директорию для логов
mkdir -p "$LOG_DIR"

# Проверить наличие конфигов
if [ ! -d "$CONFIGS_DIR" ] || [ -z "$(ls -A "$CONFIGS_DIR"/*.conf 2>/dev/null)" ]; then
    echo -e "${RED}Ошибка: Конфиги не найдены в $CONFIGS_DIR${NC}"
    echo "Запустите сначала: ./scripts/gen-enterprise-variants.sh"
    exit 1
fi

# Подсчитать количество конфигов
TOTAL_CONFIGS=$(ls -1 "$CONFIGS_DIR"/*.conf | wc -l | tr -d ' ')
echo -e "${GREEN}Найдено конфигов: $TOTAL_CONFIGS${NC}"
echo

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

# Функция для запуска одного конфига
test_config() {
    local conf="$1"
    local index="$2"
    local total="$3"
    local basename=$(basename "$conf" .conf)
    local logfile="$LOG_DIR/${basename}_$(date +%Y%m%d_%H%M%S).log"
    
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}[$index/$total] Тестирование: $basename${NC}"
    echo -e "${BLUE}=================================${NC}"
    echo "Конфиг: $conf"
    echo "Лог: $logfile"
    echo
    
    # Отключить управление NetworkManager
    sudo nmcli dev set wlx001f0566a9c0 managed no >/dev/null 2>&1 || true
    
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
    echo -e "${YELLOW}Пауза 3 секунды перед следующим конфигом...${NC}"
    sleep 3
    echo
}

# Основной цикл
index=1
for conf in "$CONFIGS_DIR"/*.conf; do
    test_config "$conf" "$index" "$TOTAL_CONFIGS"
    ((index++))
done

echo -e "${BLUE}=================================${NC}"
echo -e "${GREEN}✓ Тестирование завершено!${NC}"
echo -e "${BLUE}=================================${NC}"
echo
echo "Логи сохранены в: $LOG_DIR"
echo "Всего протестировано конфигов: $TOTAL_CONFIGS"
echo
echo "Для просмотра логов:"
echo "  ls -lt $LOG_DIR"
echo "  less $LOG_DIR/<имя_файла>.log"
