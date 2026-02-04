#!/usr/bin/env bash
# Скрипт для очистки сгенерированных конфигов

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATED_DIR="$SCRIPT_DIR/../hostapd/generated"

echo "Удаление сгенерированных конфигов из: $GENERATED_DIR"

if [ -d "$GENERATED_DIR" ]; then
    # Удалить только .conf файлы, оставить .gitkeep
    rm -f "$GENERATED_DIR"/*.conf
    echo "✓ Конфиги удалены"
    echo
    echo "Для регенерации запустите:"
    echo "  $SCRIPT_DIR/gen-enterprise-variants.sh"
else
    echo "✗ Директория $GENERATED_DIR не найдена"
    exit 1
fi
