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

# RADIUS configuration (embedded)
auth_server_addr=127.0.0.1
auth_server_port=1812
auth_server_shared_secret=testing123

acct_server_addr=127.0.0.1
acct_server_port=1813
acct_server_shared_secret=testing123

own_ip_addr=127.0.0.1

ieee8021x=1
eapol_version=2
auth_algs=1

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
V1_NAME="WPA2Ent-CCMP-P0"
V1_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=CCMP
ieee80211w=0
B
)

# 2) WPA2-Enterprise (AKM: WPA-EAP), CCMP, PMF optional
V2_NAME="WPA2Ent-CCMP-P1"
V2_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=CCMP
ieee80211w=1
B
)

# 3) WPA2-Enterprise (AKM: WPA-EAP), CCMP, PMF required
V3_NAME="WPA2Ent-CCMP-P2"
V3_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=CCMP
ieee80211w=2
B
)

# 4) WPA2-Enterprise SHA256 AKM (WPA-EAP-SHA256), CCMP, PMF required
V4_NAME="WPA2Ent-SHA256-CCMP-P2"
V4_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP-SHA256
rsn_pairwise=CCMP
ieee80211w=2
B
)

# 5) WPA2 mixed AKM (WPA-EAP + WPA-EAP-SHA256), CCMP, PMF optional
V5_NAME="WPA2Ent-Mix-CCMP-P1"
V5_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP WPA-EAP-SHA256
rsn_pairwise=CCMP
ieee80211w=1
B
)

# 6) WPA2-Enterprise + GCMP (если драйвер/чип поддерживает)
V6_NAME="WPA2Ent-GCMP-P1"
V6_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=GCMP
ieee80211w=1
B
)

# 7) Suite-B 192 (WPA3-Enterprise 192-bit)
# ⚠️ Может НЕ поддерживаться адаптером/драйвером. Если hostapd упадёт — просто пропусти этот конфиг.
V7_NAME="WPA3Ent-192b-P2"
V7_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP-SUITE-B-192
rsn_pairwise=GCMP-256
ieee80211w=2
B
)

# 8) WPA/WPA2-Enterprise mixed, TKIP only (legacy), PMF off
V8_NAME="WPA-WPA2Ent-TKIP-P0"
V8_BODY=$(cat <<'B'
wpa=3
wpa_key_mgmt=WPA-EAP
wpa_pairwise=TKIP
rsn_pairwise=CCMP
ieee80211w=0
B
)

# 9) WPA/WPA2-Enterprise mixed, TKIP+CCMP, PMF off
V9_NAME="WPA-WPA2Ent-TKIP-CCMP-P0"
V9_BODY=$(cat <<'B'
wpa=3
wpa_key_mgmt=WPA-EAP
wpa_pairwise=TKIP CCMP
rsn_pairwise=CCMP
ieee80211w=0
B
)

# 10) WPA/WPA2-Enterprise mixed, TKIP+CCMP, PMF optional
V10_NAME="WPA-WPA2Ent-TKIP-CCMP-P1"
V10_BODY=$(cat <<'B'
wpa=3
wpa_key_mgmt=WPA-EAP
wpa_pairwise=TKIP CCMP
rsn_pairwise=CCMP
ieee80211w=1
B
)

# 11) WPA-Enterprise only (legacy WPA1), TKIP, PMF off
V11_NAME="WPA1Ent-TKIP-P0"
V11_BODY=$(cat <<'B'
wpa=1
wpa_key_mgmt=WPA-EAP
wpa_pairwise=TKIP
ieee80211w=0
B
)

# 12) WPA2-Enterprise, CCMP+GCMP mixed cipher, PMF optional
V12_NAME="WPA2Ent-CCMP-GCMP-P1"
V12_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=CCMP GCMP
ieee80211w=1
B
)

# 13) WPA2-Enterprise SHA256, CCMP, PMF optional (не required)
V13_NAME="WPA2Ent-SHA256-CCMP-P1"
V13_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP-SHA256
rsn_pairwise=CCMP
ieee80211w=1
B
)

# 14) WPA2-Enterprise mixed AKM, CCMP, PMF required
V14_NAME="WPA2Ent-Mix-CCMP-P2"
V14_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP WPA-EAP-SHA256
rsn_pairwise=CCMP
ieee80211w=2
B
)

# 15) WPA2-Enterprise, GCMP, PMF required
V15_NAME="WPA2Ent-GCMP-P2"
V15_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=GCMP
ieee80211w=2
B
)

# 16) WPA2-Enterprise SHA256, GCMP, PMF required
V16_NAME="WPA2Ent-SHA256-GCMP-P2"
V16_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP-SHA256
rsn_pairwise=GCMP
ieee80211w=2
B
)

# 17) WPA/WPA2-Enterprise, CCMP only (no TKIP), PMF off
V17_NAME="WPA-WPA2Ent-CCMP-P0"
V17_BODY=$(cat <<'B'
wpa=3
wpa_key_mgmt=WPA-EAP
wpa_pairwise=CCMP
rsn_pairwise=CCMP
ieee80211w=0
B
)

# 18) WPA2-Enterprise, CCMP, PMF off (но с 802.11n отключенным для совместимости)
V18_NAME="WPA2Ent-CCMP-P0-Leg"
V18_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=CCMP
ieee80211w=0
# Без 802.11n для максимальной совместимости
B
)

# 19) WPA2/WPA3-Enterprise mixed (WPA-EAP + Suite-B-192), PMF required
V19_NAME="WPA2WPA3-CCMP-G256-P2"
V19_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP WPA-EAP-SUITE-B-192
rsn_pairwise=CCMP GCMP-256
ieee80211w=2
B
)

# 20) WPA2/WPA3-Enterprise mixed (SHA256 + Suite-B-192), PMF required
V20_NAME="W2SHA-W3-CG256-P2"
V20_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP-SHA256 WPA-EAP-SUITE-B-192
rsn_pairwise=CCMP GCMP-256
ieee80211w=2
B
)

# 21) WPA2/WPA3-Enterprise mixed (все три AKM), PMF required
V21_NAME="W2W3-ALL-CG256-P2"
V21_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP WPA-EAP-SHA256 WPA-EAP-SUITE-B-192
rsn_pairwise=CCMP GCMP-256
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
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V8_NAME}" "${extra}"$'\n'"${V8_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V9_NAME}" "${extra}"$'\n'"${V9_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V10_NAME}" "${extra}"$'\n'"${V10_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V11_NAME}" "${extra}"$'\n'"${V11_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V12_NAME}" "${extra}"$'\n'"${V12_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V13_NAME}" "${extra}"$'\n'"${V13_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V14_NAME}" "${extra}"$'\n'"${V14_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V15_NAME}" "${extra}"$'\n'"${V15_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V16_NAME}" "${extra}"$'\n'"${V16_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V17_NAME}" "${extra}"$'\n'"${V17_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V18_NAME}" "${extra}"$'\n'"${V18_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V19_NAME}" "${extra}"$'\n'"${V19_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V20_NAME}" "${extra}"$'\n'"${V20_BODY}"
  write_cfg "$band" "$hw_mode" "$channel" "LAB-${band}-${V21_NAME}" "${extra}"$'\n'"${V21_BODY}"
}

# 2.4 GHz
gen_all "24" "g" "${CH_24}" ""

# 5 GHz (добавим 11ac)
gen_all "5G" "a" "${CH_5}" $'ieee80211ac=1'

echo
echo "DONE. Конфиги лежат в: $OUT"
echo "Подсказка: ls -1 $OUT"
