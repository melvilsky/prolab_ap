#!/usr/bin/env bash
set -euo pipefail

IFACE="${IFACE:-wlx001f0566a9c0}"
OUT="${OUT:-$(dirname "$0")/../hostapd/generated}"
COMMON="${COMMON:-$(dirname "$0")/../hostapd/common/radius.conf}"

mkdir -p "$OUT"

write_cfg() {
  local band="$1" hw_mode="$2" channel="$3" ssid="$4" body="$5"
  local fname="${OUT}/${ssid}.conf"
  tee "$fname" >/dev/null <<CFG
interface=${IFACE}
driver=nl80211

country_code=US
ieee80211d=1

ssid=${ssid}
hw_mode=${hw_mode}
channel=${channel}

wmm_enabled=1
ieee80211n=1

${body}

include=${COMMON}

logger_stdout=-1
logger_stdout_level=2
CFG
  echo "OK: $fname"
}

# ---------- Базовые параметры диапазонов ----------
# 2.4 GHz: channel 6
# 5 GHz: channel 36 (не DFS)
CH_24="6"
CH_5="36"

# ---------- Набор "детектируемых" вариаций ----------
# 1) WPA2-Enterprise (AKM: WPA-EAP), CCMP, PMF off
V1_NAME="WPA2EAP-CCMP-PMF0"
V1_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=CCMP
ieee80211w=0
B
)

# 2) WPA2-Enterprise (AKM: WPA-EAP), CCMP, PMF optional
V2_NAME="WPA2EAP-CCMP-PMF1"
V2_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=CCMP
ieee80211w=1
B
)

# 3) WPA2-Enterprise (AKM: WPA-EAP), CCMP, PMF required
V3_NAME="WPA2EAP-CCMP-PMF2"
V3_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=CCMP
ieee80211w=2
B
)

# 4) WPA2-Enterprise SHA256 AKM (WPA-EAP-SHA256), CCMP, PMF required
V4_NAME="WPA2EAPSHA256-CCMP-PMF2"
V4_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP-SHA256
rsn_pairwise=CCMP
ieee80211w=2
B
)

# 5) WPA2 mixed AKM (WPA-EAP + WPA-EAP-SHA256), CCMP, PMF optional
V5_NAME="WPA2EAP+SHA256-CCMP-PMF1"
V5_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP WPA-EAP-SHA256
rsn_pairwise=CCMP
ieee80211w=1
B
)

# 6) WPA2-Enterprise + GCMP (если драйвер/чип поддерживает)
V6_NAME="WPA2EAP-GCMP-PMF1"
V6_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=GCMP
ieee80211w=1
B
)

# 7) Suite-B 192 (WPA3-Enterprise 192-bit)
# ⚠️ Может НЕ поддерживаться адаптером/драйвером. Если hostapd упадёт — просто пропусти этот конфиг.
V7_NAME="WPA3EAP-SUITEB192-PMF2"
V7_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP-SUITE-B-192
rsn_pairwise=GCMP-256
ieee80211w=2
B
)

# ---------- Генерация для 2.4G и 5G ----------
# В SSID мы кодируем: диапазон + вариант
# Пример: LAB-24-WPA2EAP-CCMP-PMF0

gen_all() {
  local band="$1" hw_mode="$2" channel="$3" extra="$4"

  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V1_NAME}" "${extra}"$'\n'"${V1_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V2_NAME}" "${extra}"$'\n'"${V2_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V3_NAME}" "${extra}"$'\n'"${V3_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V4_NAME}" "${extra}"$'\n'"${V4_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V5_NAME}" "${extra}"$'\n'"${V5_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V6_NAME}" "${extra}"$'\n'"${V6_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V7_NAME}" "${extra}"$'\n'"${V7_BODY}"
}

# 2.4 GHz
gen_all "24" "g" "${CH_24}" ""

# 5 GHz (добавим 11ac)
gen_all "5G" "a" "${CH_5}" $'ieee80211ac=1'

echo
echo "DONE. Конфиги лежат в: $OUT"
echo "Подсказка: ls -1 $OUT"
