#!/usr/bin/env bash
# PRO LAB - Главный скрипт управления
# Единая точка входа для всех операций

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Пути
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/hostapd/generated"

# Конфигурация (автодетект интерфейса)
detect_wifi_interface() {
    # Попробовать найти Wi-Fi интерфейс автоматически
    local iface=$(iw dev 2>/dev/null | grep Interface | head -1 | awk '{print $2}')
    if [ -z "$iface" ]; then
        iface="wlx001f0566a9c0"  # fallback
    fi
    echo "$iface"
}

WIFI_IFACE="${WIFI_IFACE:-$(detect_wifi_interface)}"

# Заголовок
show_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}PRO LAB${NC} - Enterprise WiFi Testing Framework       ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "📡 Wi-Fi интерфейс: ${GREEN}$WIFI_IFACE${NC}"
    echo
}

# Главное меню
show_menu() {
    show_header
    echo -e "${BOLD}Главное меню:${NC}"
    echo
    echo "  ${CYAN}1${NC}) 🚀 Запустить AP (выбор конфига)"
    echo "  ${CYAN}2${NC}) 📊 Показать все конфиги"
    echo "  ${CYAN}3${NC}) 🔄 Сгенерировать конфиги"
    echo "  ${CYAN}4${NC}) ✅ Проверить систему"
    echo "  ${CYAN}5${NC}) 🧪 Автотест всех конфигов"
    echo "  ${CYAN}6${NC}) ⚙️  Настройки"
    echo "  ${CYAN}7${NC}) 📚 Документация"
    echo "  ${CYAN}q${NC}) Выход"
    echo
    echo -n "Выберите действие: "
}

# Показать все конфиги с описанием
show_configs() {
    show_header
    echo -e "${BOLD}📊 Доступные конфигурации:${NC}"
    echo
    
    if [ ! -d "$CONFIGS_DIR" ] || [ -z "$(ls -A "$CONFIGS_DIR"/*.conf 2>/dev/null)" ]; then
        echo -e "${YELLOW}⚠ Конфиги не найдены. Сгенерируйте их (опция 3)${NC}"
        echo
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "${BOLD}%-3s %-40s %-15s${NC}\n" "№" "SSID" "Параметры"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local i=1
    for conf in "$CONFIGS_DIR"/*.conf; do
        local basename=$(basename "$conf" .conf)
        local ssid=$(grep "^ssid=" "$conf" | cut -d= -f2)
        
        # Определить параметры по имени
        local params=""
        if [[ "$basename" =~ "24" ]]; then
            params="${GREEN}2.4G${NC}"
        elif [[ "$basename" =~ "5G" ]]; then
            params="${GREEN}5GHz${NC}"
        fi
        
        if [[ "$basename" =~ "PMF0" ]]; then
            params="$params ${RED}PMF:off${NC}"
        elif [[ "$basename" =~ "PMF1" ]]; then
            params="$params ${YELLOW}PMF:opt${NC}"
        elif [[ "$basename" =~ "PMF2" ]]; then
            params="$params ${GREEN}PMF:req${NC}"
        fi
        
        if [[ "$basename" =~ "SHA256" ]]; then
            params="$params ${CYAN}SHA256${NC}"
        fi
        
        if [[ "$basename" =~ "GCMP" ]]; then
            params="$params ${BLUE}GCMP${NC}"
        elif [[ "$basename" =~ "SUITEB" ]]; then
            params="$params ${BOLD}Suite-B${NC}"
        fi
        
        printf "%-3s %-40s %b\n" "$i" "$ssid" "$params"
        ((i++))
    done
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# Выбор и запуск конфига
run_ap() {
    show_configs
    
    if [ ! -d "$CONFIGS_DIR" ] || [ -z "$(ls -A "$CONFIGS_DIR"/*.conf 2>/dev/null)" ]; then
        return
    fi
    
    local total=$(ls -1 "$CONFIGS_DIR"/*.conf | wc -l | tr -d ' ')
    echo -n "Выберите конфиг (1-$total) или 'q' для выхода: "
    read choice
    
    if [ "$choice" = "q" ]; then
        return
    fi
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$total" ]; then
        echo -e "${RED}✗ Неверный выбор${NC}"
        sleep 2
        return
    fi
    
    local conf=$(ls -1 "$CONFIGS_DIR"/*.conf | sed -n "${choice}p")
    local ssid=$(basename "$conf" .conf)
    
    echo
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}▶ Запуск AP: $ssid${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}💡 Подсказка:${NC}"
    echo "   • Для остановки нажмите Ctrl+C"
    echo "   • Подключитесь к SSID: $ssid"
    echo "   • User: testuser / Pass: testpass"
    echo
    echo -e "${YELLOW}⚠ Убедитесь, что FreeRADIUS запущен в другом терминале!${NC}"
    echo "   Команда: ${CYAN}sudo freeradius -X${NC}"
    echo
    read -p "Нажмите Enter для запуска..."
    
    # Отключить NetworkManager
    sudo nmcli dev set "$WIFI_IFACE" managed no >/dev/null 2>&1 || true
    
    # Запустить hostapd
    sudo hostapd -dd "$conf"
}

# Генерация конфигов
generate_configs() {
    show_header
    echo -e "${BOLD}🔄 Генерация конфигураций${NC}"
    echo
    
    if [ -d "$CONFIGS_DIR" ] && [ -n "$(ls -A "$CONFIGS_DIR"/*.conf 2>/dev/null)" ]; then
        echo -e "${YELLOW}⚠ Конфиги уже существуют${NC}"
        echo -n "Перегенерировать? (y/n): "
        read answer
        if [ "$answer" != "y" ]; then
            return
        fi
        rm -f "$CONFIGS_DIR"/*.conf
    fi
    
    echo -e "${GREEN}▶ Генерация конфигов для интерфейса: $WIFI_IFACE${NC}"
    echo
    
    export IFACE="$WIFI_IFACE"
    "$SCRIPT_DIR/scripts/gen-enterprise-variants.sh"
    
    echo
    echo -e "${GREEN}✓ Готово!${NC}"
    sleep 2
}

# Проверка системы
check_system() {
    show_header
    echo -e "${BOLD}✅ Проверка системы${NC}"
    echo
    
    if [ -x "$SCRIPT_DIR/scripts/check-system.sh" ]; then
        "$SCRIPT_DIR/scripts/check-system.sh"
    else
        echo -e "${RED}✗ Скрипт check-system.sh не найден${NC}"
    fi
    
    echo
    read -p "Нажмите Enter для продолжения..."
}

# Автотест
auto_test() {
    show_header
    echo -e "${BOLD}🧪 Автоматическое тестирование${NC}"
    echo
    echo -n "Длительность теста каждого конфига (секунды, по умолчанию 30): "
    read duration
    duration=${duration:-30}
    
    echo
    echo -e "${YELLOW}⚠ Убедитесь, что FreeRADIUS запущен!${NC}"
    echo
    read -p "Нажмите Enter для начала тестирования..."
    
    "$SCRIPT_DIR/scripts/test-all-configs.sh" "$duration"
    
    echo
    read -p "Нажмите Enter для продолжения..."
}

# Настройки
settings_menu() {
    show_header
    echo -e "${BOLD}⚙️  Настройки${NC}"
    echo
    echo "1) Изменить Wi-Fi интерфейс (текущий: ${GREEN}$WIFI_IFACE${NC})"
    echo "2) Назад"
    echo
    echo -n "Выберите: "
    read choice
    
    case $choice in
        1)
            echo
            echo "Доступные интерфейсы:"
            iw dev 2>/dev/null | grep Interface | awk '{print "  • " $2}'
            echo
            echo -n "Введите имя интерфейса: "
            read new_iface
            if [ -n "$new_iface" ]; then
                export WIFI_IFACE="$new_iface"
                echo -e "${GREEN}✓ Интерфейс изменен на: $new_iface${NC}"
                echo "Не забудьте перегенерировать конфиги!"
                sleep 3
            fi
            ;;
    esac
}

# Документация
show_docs() {
    show_header
    echo -e "${BOLD}📚 Документация${NC}"
    echo
    echo "Доступные документы:"
    echo
    echo "  ${CYAN}1${NC}) README.md - Основная документация"
    echo "  ${CYAN}2${NC}) QUICKSTART.md - Быстрый старт"
    echo "  ${CYAN}3${NC}) EXAMPLES.md - Примеры использования"
    echo "  ${CYAN}4${NC}) CONFIGS_MATRIX.md - Матрица конфигов"
    echo "  ${CYAN}5${NC}) GETTING_STARTED.md - С чего начать"
    echo
    echo "  ${CYAN}0${NC}) Назад"
    echo
    echo -n "Выберите документ для просмотра: "
    read doc_choice
    
    case $doc_choice in
        1) less "$SCRIPT_DIR/README.md" 2>/dev/null || cat "$SCRIPT_DIR/README.md" ;;
        2) less "$SCRIPT_DIR/QUICKSTART.md" 2>/dev/null || cat "$SCRIPT_DIR/QUICKSTART.md" ;;
        3) less "$SCRIPT_DIR/EXAMPLES.md" 2>/dev/null || cat "$SCRIPT_DIR/EXAMPLES.md" ;;
        4) less "$SCRIPT_DIR/CONFIGS_MATRIX.md" 2>/dev/null || cat "$SCRIPT_DIR/CONFIGS_MATRIX.md" ;;
        5) less "$SCRIPT_DIR/GETTING_STARTED.md" 2>/dev/null || cat "$SCRIPT_DIR/GETTING_STARTED.md" ;;
    esac
}

# Главный цикл
main() {
    while true; do
        show_menu
        read choice
        
        case $choice in
            1) run_ap ;;
            2) show_configs; read -p "Нажмите Enter для продолжения..." ;;
            3) generate_configs ;;
            4) check_system ;;
            5) auto_test ;;
            6) settings_menu ;;
            7) show_docs ;;
            q|Q) echo -e "\n${GREEN}До свидания!${NC}"; exit 0 ;;
            *) echo -e "${RED}Неверный выбор${NC}"; sleep 1 ;;
        esac
    done
}

# Проверка: если запущен с параметром --quick, сразу показать конфиги и запустить
if [ "$1" = "--quick" ]; then
    run_ap
    exit 0
fi

# Запуск
main
