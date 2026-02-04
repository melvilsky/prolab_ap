#!/usr/bin/env bash
set -e

CFG="$1"
if [ -z "${CFG:-}" ]; then
  echo "Usage: $0 /path/to/hostapd.conf"
  exit 1
fi

# чтоб NM не мешал hostapd
sudo nmcli dev set wlx001f0566a9c0 managed no >/dev/null 2>&1 || true

sudo hostapd -dd "$CFG"
