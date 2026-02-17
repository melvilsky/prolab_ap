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
CONFIG_MODE="${CONFIG_MODE:-security}"  # security или channel-widths
if [ "$CONFIG_MODE" = "channel-widths" ]; then
    CONFIGS_DIR="$SCRIPT_DIR/hostapd/channel-widths"
else
    CONFIGS_DIR="$SCRIPT_DIR/hostapd/generated"
fi

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

# ---------- Preflight / Environment Check ----------
PREFLIGHT_DONE=0
PREFLIGHT_ERRORS=0
PREFLIGHT_WARNINGS=0
PREFLIGHT_LINES=""

# Capability flags (best-effort)
SUPPORT_AP_MODE=0
SUPPORT_GCMP=0
SUPPORT_GCMP256=0
SUPPORT_SHA256_AKM=0
SUPPORT_SUITEB=0
SUPPORT_PMF=0

preflight_add() {
    # args: level label value
    local level="$1" label="$2" value="$3"
    PREFLIGHT_LINES="${PREFLIGHT_LINES}${level}\t${label}\t${value}\n"
}

preflight_check() {
    PREFLIGHT_DONE=1
    PREFLIGHT_ERRORS=0
    PREFLIGHT_WARNINGS=0
    PREFLIGHT_LINES=""
    SUPPORT_AP_MODE=0
    SUPPORT_GCMP=0
    SUPPORT_GCMP256=0
    SUPPORT_SHA256_AKM=0
    SUPPORT_SUITEB=0
    SUPPORT_PMF=0

    # Commands
    if command -v iw >/dev/null 2>&1; then
        preflight_add "OK" "iw" "found"
    else
        preflight_add "ERR" "iw" "missing"
        PREFLIGHT_ERRORS=$((PREFLIGHT_ERRORS + 1))
    fi

    local hostapd_path=""
    if command -v hostapd >/dev/null 2>&1; then
        hostapd_path="$(command -v hostapd)"
        preflight_add "OK" "hostapd" "$hostapd_path"
    else
        preflight_add "ERR" "hostapd" "missing"
        PREFLIGHT_ERRORS=$((PREFLIGHT_ERRORS + 1))
    fi

    if command -v freeradius >/dev/null 2>&1; then
        preflight_add "OK" "freeradius" "found"
    else
        preflight_add "WARN" "freeradius" "binary not found (but service may exist)"
        PREFLIGHT_WARNINGS=$((PREFLIGHT_WARNINGS + 1))
    fi

    # Interface state
    if command -v ip >/dev/null 2>&1 && ip link show "$WIFI_IFACE" >/dev/null 2>&1; then
        local state_line
        state_line="$(ip link show "$WIFI_IFACE" | head -n 1)"
        if echo "$state_line" | grep -q "UP"; then
            preflight_add "OK" "Interface" "$WIFI_IFACE (UP)"
        else
            preflight_add "WARN" "Interface" "$WIFI_IFACE (DOWN) → sudo ip link set $WIFI_IFACE up"
            PREFLIGHT_WARNINGS=$((PREFLIGHT_WARNINGS + 1))
        fi
    else
        preflight_add "ERR" "Interface" "$WIFI_IFACE not found"
        PREFLIGHT_ERRORS=$((PREFLIGHT_ERRORS + 1))
    fi

    # AP mode / ciphers (from iw list)
    if command -v iw >/dev/null 2>&1; then
        if iw list 2>/dev/null | grep -qE '^[[:space:]]*\\*[[:space:]]+AP$'; then
            SUPPORT_AP_MODE=1
            preflight_add "OK" "AP mode" "supported"
        else
            SUPPORT_AP_MODE=0
            preflight_add "ERR" "AP mode" "NOT supported (adapter/driver)"
            PREFLIGHT_ERRORS=$((PREFLIGHT_ERRORS + 1))
        fi

        if iw list 2>/dev/null | grep -q "CCMP"; then
            preflight_add "OK" "Cipher CCMP" "supported"
        else
            preflight_add "WARN" "Cipher CCMP" "not detected (unexpected)"
            PREFLIGHT_WARNINGS=$((PREFLIGHT_WARNINGS + 1))
        fi

        if iw list 2>/dev/null | grep -q "GCMP"; then
            SUPPORT_GCMP=1
            preflight_add "OK" "Cipher GCMP" "supported"
        else
            SUPPORT_GCMP=0
            preflight_add "WARN" "Cipher GCMP" "not supported → GCMP профили могут падать"
            PREFLIGHT_WARNINGS=$((PREFLIGHT_WARNINGS + 1))
        fi

        if iw list 2>/dev/null | grep -qi "GCMP-256"; then
            SUPPORT_GCMP256=1
            preflight_add "OK" "Cipher GCMP-256" "supported"
        else
            SUPPORT_GCMP256=0
            preflight_add "WARN" "Cipher GCMP-256" "not supported → Suite-B/WPA3-192 профили могут падать"
            PREFLIGHT_WARNINGS=$((PREFLIGHT_WARNINGS + 1))
        fi

        # Regulatory domain (informational)
        if iw reg get >/dev/null 2>&1; then
            local reg
            reg="$(iw reg get 2>/dev/null | awk '/country/ {print $2; exit}' | tr -d ':')"
            [ -n "$reg" ] && preflight_add "OK" "Regdomain" "$reg"
        fi
    fi

    # hostapd feature hints (best-effort, from strings)
    if [ -n "$hostapd_path" ] && command -v strings >/dev/null 2>&1; then
        if strings "$hostapd_path" 2>/dev/null | grep -q "WPA-EAP-SHA256"; then
            SUPPORT_SHA256_AKM=1
            preflight_add "OK" "AKM SHA256" "hostapd supports"
        else
            SUPPORT_SHA256_AKM=0
            preflight_add "WARN" "AKM SHA256" "not detected in hostapd → SHA256 профили могут падать"
            PREFLIGHT_WARNINGS=$((PREFLIGHT_WARNINGS + 1))
        fi

        if strings "$hostapd_path" 2>/dev/null | grep -q "WPA-EAP-SUITE-B-192"; then
            SUPPORT_SUITEB=1
            preflight_add "OK" "Suite-B-192" "hostapd supports"
        else
            SUPPORT_SUITEB=0
            preflight_add "WARN" "Suite-B-192" "not detected in hostapd → WPA3-192 профили могут падать"
            PREFLIGHT_WARNINGS=$((PREFLIGHT_WARNINGS + 1))
        fi

        if strings "$hostapd_path" 2>/dev/null | grep -q "ieee80211w"; then
            SUPPORT_PMF=1
            preflight_add "OK" "PMF (802.11w)" "hostapd supports (best-effort)"
        else
            SUPPORT_PMF=0
            preflight_add "WARN" "PMF (802.11w)" "not detected in hostapd → PMF профили могут падать"
            PREFLIGHT_WARNINGS=$((PREFLIGHT_WARNINGS + 1))
        fi
    fi

    # hostapd version (informational + mild heuristic)
    if [ -n "$hostapd_path" ]; then
        local hv
        hv="$(hostapd -v 2>&1 | head -n 1 | tr -d '\r')"
        if [ -n "$hv" ]; then
            preflight_add "OK" "hostapd version" "$hv"
            if echo "$hv" | grep -qE 'v2\.[0-6]([[:space:]]|$)'; then
                preflight_add "WARN" "hostapd version" "seems old → WPA3/SHA256 may be broken"
                PREFLIGHT_WARNINGS=$((PREFLIGHT_WARNINGS + 1))
            fi
        fi
    fi

    # FreeRADIUS running
    if pgrep -x "freeradius" >/dev/null 2>&1 || pgrep -x "radiusd" >/dev/null 2>&1; then
        preflight_add "OK" "FreeRADIUS" "running"
    else
        preflight_add "WARN" "FreeRADIUS" "not running → sudo freeradius -X"
        PREFLIGHT_WARNINGS=$((PREFLIGHT_WARNINGS + 1))
    fi
}

preflight_print() {
    echo -e "${BOLD}Preflight Check${NC}"
    echo -e "${CYAN}--------------------------------${NC}"
    # Print table
    printf "%-3s %-18s %s\n" " " "Check" "Result"
    echo -e "${CYAN}--------------------------------${NC}"
    printf "%b" "$PREFLIGHT_LINES" | while IFS=$'\t' read -r level label value; do
        case "$level" in
            OK)   printf "%b %-18s %s\n" "${GREEN}✓${NC}" "$label" "$value" ;;
            WARN) printf "%b %-18s %s\n" "${YELLOW}!${NC}" "$label" "$value" ;;
            ERR)  printf "%b %-18s %s\n" "${RED}✗${NC}" "$label" "$value" ;;
        esac
    done
    echo -e "${CYAN}--------------------------------${NC}"
    if [ "$PREFLIGHT_ERRORS" -gt 0 ]; then
        echo -e "${RED}Ошибки: $PREFLIGHT_ERRORS${NC}  ${YELLOW}Предупреждения: $PREFLIGHT_WARNINGS${NC}"
    else
        echo -e "${GREEN}Ошибок нет${NC}  ${YELLOW}Предупреждения: $PREFLIGHT_WARNINGS${NC}"
    fi
    echo
}

# Заголовок
show_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${BOLD}PRO LAB${NC} - Enterprise WiFi Testing Framework       ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "📡 Wi-Fi интерфейс: ${GREEN}$WIFI_IFACE${NC}"
    if [ "$CONFIG_MODE" = "channel-widths" ]; then
        echo -e "📁 Режим: ${CYAN}Ширина каналов${NC} (${YELLOW}hostapd/channel-widths${NC})"
    else
        echo -e "📁 Режим: ${CYAN}Безопасность${NC} (${YELLOW}hostapd/generated${NC})"
    fi
    echo
    if [ "$PREFLIGHT_DONE" -eq 1 ]; then
        if [ "$PREFLIGHT_ERRORS" -gt 0 ]; then
            echo -e "${RED}Preflight:${NC} ошибки=$PREFLIGHT_ERRORS, предупреждения=$PREFLIGHT_WARNINGS (опция 4 для деталей)"
        else
            echo -e "${GREEN}Preflight:${NC} OK, предупреждения=$PREFLIGHT_WARNINGS (опция 4 для деталей)"
        fi
        echo
    fi
}

# Главное меню
show_menu() {
    show_header
    echo -e "${BOLD}Главное меню:${NC}"
    echo
    echo "  1) 🚀 Запустить AP (выбор конфига)"
    echo "  2) 📊 Показать все конфиги"
    echo "  3) 🔄 Сгенерировать конфиги"
    echo "  4) ✅ Проверить систему"
    echo "  5) 🧪 Автотест всех конфигов"
    echo "  6) ⏭ Полуавто (Enter=следующий)"
    echo "  7) 🔄 Обновить лабу (git pull + regen)"
    echo "  8) ⚙️  Настройки"
    echo "  9) 📚 Документация"
    echo "  q) Выход"
    echo
    local index_file="$CONFIGS_DIR/index.tsv"
    local total=""
    if [ -f "$index_file" ]; then
        total=$(wc -l < "$index_file" | tr -d ' ')
    else
        total=$(ls -1 "$CONFIGS_DIR"/*.conf 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ -n "$total" ] && [ "$total" -gt 0 ]; then
        echo -e "  ${BOLD}Профили:${NC} 01–${total}   ${BOLD}Список:${NC} опция 2"
    fi
    echo
    echo -n "Выберите действие: "
}

# По флагам preflight вернуть причину неподдержки (пусто = поддерживается)
profile_unsupported_reason() {
    local base="$1" reason=""
    # WPA3 / Suite-B / GCMP-256 (WPA3Ent-192, W2E3E, W2E-SHA-W3E*)
    if [[ "$base" =~ (G256|WPA3Ent-192|W2E3E|W2E-SHA-W3E) ]]; then
        [ "$SUPPORT_GCMP256" -eq 0 ] && reason="${reason}GCMP-256 "
        [ "$SUPPORT_SUITEB" -eq 0 ] && reason="${reason}Suite-B "
    fi
    # GCMP (без G256): WPA2Ent-GCMP-*, WPA2Ent-CCMP-GCMP-*, WPA2Ent-SHA256-GCMP-*
    if [[ "$base" =~ GCMP ]] && ! [[ "$base" =~ G256 ]]; then
        [ "$SUPPORT_GCMP" -eq 0 ] && reason="${reason}GCMP "
    fi
    # AKM SHA256
    if [[ "$base" =~ SHA ]]; then
        [ "$SUPPORT_SHA256_AKM" -eq 0 ] && reason="${reason}SHA256 "
    fi
    # PMF required (P2)
    if [[ "$base" =~ -P2 ]]; then
        [ "$SUPPORT_PMF" -eq 0 ] && reason="${reason}PMF "
    fi
    # trim
    echo "$reason" | sed 's/ *$//'
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
    printf "${BOLD}%-3s %-42s %s${NC}\n" "№" "SSID" "Параметры"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    local index_file="$CONFIGS_DIR/index.tsv"
    if [ -f "$index_file" ]; then
        while IFS=$'\t' read -r num profile ssid; do
            local basename="${profile%.conf}"
            # Определить параметры по имени профиля
            local params=""
            if [[ "$basename" =~ "24" ]]; then
                params="${GREEN}2.4G${NC}"
            elif [[ "$basename" =~ "5G" ]]; then
                params="${GREEN}5GHz${NC}"
            fi
            
            if [[ "$basename" =~ "-P0" ]]; then
                params="$params ${RED}PMF:off${NC}"
            elif [[ "$basename" =~ "-P1" ]]; then
                params="$params ${YELLOW}PMF:opt${NC}"
            elif [[ "$basename" =~ "-P2" ]]; then
                params="$params ${GREEN}PMF:req${NC}"
            fi
            
            if [[ "$basename" =~ "SHA" ]]; then
                params="$params ${CYAN}SHA256${NC}"
            fi
            
            if [[ "$basename" =~ "W3" ]]; then
                params="$params ${BOLD}WPA3${NC}"
            fi
            
            if [[ "$basename" =~ "GCMP" ]] || [[ "$basename" =~ "G256" ]]; then
                params="$params ${BLUE}GCMP${NC}"
            fi
            
            if [[ "$basename" =~ "TKIP" ]]; then
                params="$params ${RED}TKIP${NC}"
            fi
            
            # Capability-based: пометка "unsupported by adapter"
            local unsupp
            unsupp="$(profile_unsupported_reason "$basename")"
            if [ -n "$unsupp" ]; then
                params="$params  ${RED}❌ unsupported by adapter (no $unsupp)${NC}"
            fi
            
            printf "%-3s %-42s %b\n" "$num" "$ssid" "$params"
        done < "$index_file"
    else
        local i=1
        for conf in $(ls -1 "$CONFIGS_DIR"/*.conf | sort); do
            local basename=$(basename "$conf" .conf)
            local ssid=$(grep "^ssid=" "$conf" | cut -d= -f2)
        
            # Определить параметры по имени
            local params=""
            if [[ "$basename" =~ "24" ]]; then
                params="${GREEN}2.4G${NC}"
            elif [[ "$basename" =~ "5G" ]]; then
                params="${GREEN}5GHz${NC}"
            fi
            
            if [[ "$basename" =~ "-P0" ]]; then
                params="$params ${RED}PMF:off${NC}"
            elif [[ "$basename" =~ "-P1" ]]; then
                params="$params ${YELLOW}PMF:opt${NC}"
            elif [[ "$basename" =~ "-P2" ]]; then
                params="$params ${GREEN}PMF:req${NC}"
            fi
            
            if [[ "$basename" =~ "SHA" ]]; then
                params="$params ${CYAN}SHA256${NC}"
            fi
            
            if [[ "$basename" =~ "W3" ]]; then
                params="$params ${BOLD}WPA3${NC}"
            fi
            
            if [[ "$basename" =~ "GCMP" ]] || [[ "$basename" =~ "G256" ]]; then
                params="$params ${BLUE}GCMP${NC}"
            fi
            
            if [[ "$basename" =~ "TKIP" ]]; then
                params="$params ${RED}TKIP${NC}"
            fi
            
            # Ширина канала (для channel-widths)
            if [[ "$basename" =~ "-20M-" ]]; then
                params="$params ${CYAN}20MHz${NC}"
            elif [[ "$basename" =~ "-40M-" ]]; then
                params="$params ${CYAN}40MHz${NC}"
            elif [[ "$basename" =~ "-80M-" ]]; then
                params="$params ${CYAN}80MHz${NC}"
            elif [[ "$basename" =~ "-80p80M-" ]]; then
                params="$params ${CYAN}80+80MHz${NC}"
            elif [[ "$basename" =~ "-160M-" ]]; then
                params="$params ${CYAN}160MHz${NC}"
            elif [[ "$basename" =~ "-320M-" ]]; then
                params="$params ${CYAN}320MHz${NC}"
            fi
            
            unsupp="$(profile_unsupported_reason "$basename")"
            if [ -n "$unsupp" ]; then
                params="$params  ${RED}❌ unsupported by adapter (no $unsupp)${NC}"
            fi
            
            printf "%-3s %-42s %b\n" "$i" "$ssid" "$params"
            ((i++))
        done
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    if [ "$PREFLIGHT_DONE" -eq 1 ]; then
        echo -e "${BOLD}Легенда:${NC} ❌ = профиль не поддерживается текущим адаптером/hostapd (см. Preflight, опция 4)"
    fi
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
    
    local conf=""
    local profile=""
    local ssid=""
    local index_file="$CONFIGS_DIR/index.tsv"
    if [ -f "$index_file" ]; then
        # Используем index.tsv для стабильной нумерации (generated)
        profile=$(awk -v n="$choice" -F'\t' 'NR==n {print $2; exit}' "$index_file")
        ssid=$(awk -v n="$choice" -F'\t' 'NR==n {print $3; exit}' "$index_file")
        conf="$CONFIGS_DIR/$profile"
    else
        # Для channel-widths просто сортируем файлы
        conf=$(ls -1 "$CONFIGS_DIR"/*.conf | sort | sed -n "${choice}p")
        profile=$(basename "$conf")
        ssid=$(grep "^ssid=" "$conf" | cut -d= -f2)
    fi
    
    # Предупреждение, если профиль помечен как неподдерживаемый
    local base_name="${profile%.conf}"
    local run_unsupp
    run_unsupp="$(profile_unsupported_reason "$base_name")"
    if [ -n "$run_unsupp" ]; then
        echo -e "${YELLOW}⚠ Профиль не поддерживается адаптером/hostapd (нет: $run_unsupp).${NC}"
        echo -n "Всё равно запустить? (y/N): "
        read -r ans
        if [[ ! "$ans" =~ ^[Yy]$ ]]; then
            return
        fi
        echo
    fi
    
    echo
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}▶ Запуск профиля: $profile${NC}"
    echo -e "${CYAN}  SSID: $ssid${NC}"
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

# Проверка системы (Preflight + check-system.sh)
check_system() {
    show_header
    echo -e "${BOLD}✅ Проверка системы${NC}"
    echo
    
    preflight_check
    preflight_print
    echo -e "${BOLD}Доп. проверка (check-system.sh):${NC}"
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

# Полуавтоматический тест
semi_auto_test() {
    show_header
    echo -e "${BOLD}⏭ Полуавтоматическое тестирование${NC}"
    echo
    echo -e "${YELLOW}⚠ Убедитесь, что FreeRADIUS запущен!${NC}"
    echo
    read -p "Нажмите Enter для начала..."
    
    "$SCRIPT_DIR/scripts/test-all-configs-step.sh"
    
    echo
    read -p "Нажмите Enter для продолжения..."
}

# Обновление лабы: автоматически очистка → pull → генерация
update_lab() {
    show_header
    echo -e "${BOLD}🔄 Обновление лабы${NC}"
    echo -e "Очистка → загрузка нового → генерация конфигов..."
    echo

    (
        cd "$SCRIPT_DIR" || exit 1

        if ! command -v git >/dev/null 2>&1; then
            echo -e "${RED}✗ git не установлен${NC}"
            echo "Установите git и повторите."
            exit 1
        fi

        if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            echo -e "${RED}✗ Текущая папка не является git-репозиторием${NC}"
            echo "Проверьте, что вы запускаете lab.sh из клонированного репозитория."
            exit 1
        fi

        echo -e "${BLUE}→ Очистка hostapd/generated...${NC}"
        if [ -e "hostapd/generated" ]; then
            rm -rf "hostapd/generated" 2>/dev/null || true
        fi
        if [ -e "hostapd/generated" ]; then
            echo -e "${RED}✗ Не удалось удалить hostapd/generated${NC}"
            echo "Скорее всего, папка/файлы принадлежат root."
            echo "Исправление:"
            echo "  sudo chown -R $USER:$USER hostapd/generated"
            echo "  rm -rf hostapd/generated"
            exit 1
        fi

        echo -e "${BLUE}→ git pull --ff-only...${NC}"
        if ! git pull --ff-only; then
            echo -e "${RED}✗ Не удалось выполнить git pull --ff-only${NC}"
            echo "Возможные причины:"
            echo "  - есть локальные изменения (git status)"
            echo "  - ветка расходится с origin/main"
            echo
            echo "Безопасные варианты:"
            echo "  git status"
            echo "  git stash -u"
            echo "  git pull --ff-only"
            echo
            echo "Жёсткий вариант (удалит локальные правки):"
            echo "  git reset --hard origin/main"
            exit 1
        fi

        echo -e "${BLUE}→ Генерация конфигов...${NC}"
        if ! ./scripts/gen-enterprise-variants.sh; then
            echo -e "${RED}✗ Ошибка генерации конфигов${NC}"
            exit 1
        fi

        count=$(ls -1 hostapd/generated/*.conf 2>/dev/null | wc -l | tr -d ' ')
        if [ -f "hostapd/generated/index.tsv" ]; then
            echo -e "${GREEN}✓ Готово: ${count} конфигов, index.tsv OK${NC}"
        else
            echo -e "${YELLOW}⚠ Готово: ${count} конфигов, но index.tsv не найден${NC}"
        fi
    )

    echo
    echo -e "${GREEN}✓ Обновление завершено!${NC}"
    sleep 2
}

# Настройки
settings_menu() {
    show_header
    echo -e "${BOLD}⚙️  Настройки${NC}"
    echo
    echo "1) Изменить Wi-Fi интерфейс (текущий: ${GREEN}$WIFI_IFACE${NC})"
    echo "2) Выбрать папку конфигов"
    echo "   Текущая: ${CYAN}$CONFIG_MODE${NC}"
    if [ "$CONFIG_MODE" = "security" ]; then
        echo "   (${YELLOW}hostapd/generated${NC} — базовые конфиги безопасности)"
    else
        echo "   (${YELLOW}hostapd/channel-widths${NC} — тестирование ширины каналов)"
    fi
    echo "3) Назад"
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
        2)
            echo
            echo "Выберите папку конфигов:"
            echo "  1) Безопасность (hostapd/generated) — 42 базовых конфига"
            echo "  2) Ширина каналов (hostapd/channel-widths) — 8 конфигов"
            echo
            echo -n "Выберите (1 или 2): "
            read folder_choice
            if [ "$folder_choice" = "1" ]; then
                export CONFIG_MODE="security"
                CONFIGS_DIR="$SCRIPT_DIR/hostapd/generated"
                echo -e "${GREEN}✓ Переключено на: Безопасность${NC}"
                sleep 2
            elif [ "$folder_choice" = "2" ]; then
                export CONFIG_MODE="channel-widths"
                CONFIGS_DIR="$SCRIPT_DIR/hostapd/channel-widths"
                echo -e "${GREEN}✓ Переключено на: Ширина каналов${NC}"
                sleep 2
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
            6) semi_auto_test ;;
            7) update_lab ;;
            8) settings_menu ;;
            9) show_docs ;;
            q|Q) echo -e "\n${GREEN}До свидания!${NC}"; exit 0 ;;
            *) echo -e "${RED}Неверный выбор${NC}"; sleep 1 ;;
        esac
    done
}

# Запуск (Preflight перед меню)
preflight_check
show_header
preflight_print
echo -e "Нажмите ${BOLD}Enter${NC} для продолжения или ${BOLD}Ctrl+C${NC} для выхода."
read -r _

# Проверка: если запущен с параметром --quick, сразу показать конфиги и запустить
if [ "$1" = "--quick" ]; then
    run_ap
    exit 0
fi

main
