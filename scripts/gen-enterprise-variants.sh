#!/usr/bin/env bash
set -euo pipefail

# Generated configs must be self-contained (no include=).
IFACE="${IFACE:-wlx001f0566a9c0}"
OUT="${OUT:-$(dirname "$0")/../hostapd/generated}"
OUT_WIDTHS="${OUT_WIDTHS:-$(dirname "$0")/../hostapd/channel-widths}"

mkdir -p "$OUT"
mkdir -p "$OUT_WIDTHS"

write_cfg() {
  local output_dir="$1" band="$2" hw_mode="$3" channel="$4" ssid="$5" body="$6" chwidth_extra="$7"
  local fname="${output_dir}/${ssid}.conf"
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

${chwidth_extra}

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
V19_NAME="W2E3E-CCMP-G256-P2"
V19_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP WPA-EAP-SUITE-B-192
rsn_pairwise=CCMP GCMP-256
ieee80211w=2
B
)

# 20) WPA2/WPA3-Enterprise mixed (SHA256 + Suite-B-192), PMF required
V20_NAME="W2E-SHA-W3E-CG256-P2"
V20_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP-SHA256 WPA-EAP-SUITE-B-192
rsn_pairwise=CCMP GCMP-256
ieee80211w=2
B
)

# 21) WPA2/WPA3-Enterprise mixed (все три AKM), PMF required
V21_NAME="W2E-SHA-W3E-ALL-CG256-P2"
V21_BODY=$(cat <<'B'
wpa=2
wpa_key_mgmt=WPA-EAP WPA-EAP-SHA256 WPA-EAP-SUITE-B-192
rsn_pairwise=CCMP GCMP-256
ieee80211w=2
B
)

# ---------- Генерация базовых конфигов безопасности (без вариантов ширины канала) ----------
# В SSID: диапазон + вариант
# Пример: LAB-24-WPA2Ent-CCMP-P1, LAB-5G-WPA2Ent-CCMP-P1

gen_all_security() {
  local band="$1" hw_mode="$2" channel="$3" extra="$4"
  
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V1_NAME}" "${extra}"$'\n'"${V1_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V2_NAME}" "${extra}"$'\n'"${V2_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V3_NAME}" "${extra}"$'\n'"${V3_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V4_NAME}" "${extra}"$'\n'"${V4_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V5_NAME}" "${extra}"$'\n'"${V5_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V6_NAME}" "${extra}"$'\n'"${V6_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V7_NAME}" "${extra}"$'\n'"${V7_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V8_NAME}" "${extra}"$'\n'"${V8_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V9_NAME}" "${extra}"$'\n'"${V9_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V10_NAME}" "${extra}"$'\n'"${V10_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V11_NAME}" "${extra}"$'\n'"${V11_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V12_NAME}" "${extra}"$'\n'"${V12_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V13_NAME}" "${extra}"$'\n'"${V13_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V14_NAME}" "${extra}"$'\n'"${V14_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V15_NAME}" "${extra}"$'\n'"${V15_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V16_NAME}" "${extra}"$'\n'"${V16_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V17_NAME}" "${extra}"$'\n'"${V17_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V18_NAME}" "${extra}"$'\n'"${V18_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V19_NAME}" "${extra}"$'\n'"${V19_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V20_NAME}" "${extra}"$'\n'"${V20_BODY}" ""
  write_cfg "$OUT" "$band" "$hw_mode" "$channel" "LAB-${band}-${V21_NAME}" "${extra}"$'\n'"${V21_BODY}" ""
}

# ---------- Генерация конфигов для тестирования ширины каналов ----------
# Используем один базовый вариант безопасности (WPA2Ent-CCMP-P1) для всех ширин
# В SSID: диапазон + ширина канала + вариант
# Пример: LAB-24-40M-WPA2Ent-CCMP-P1, LAB-5G-80p80M-WPA2Ent-CCMP-P1

gen_variant_width() {
  local band="$1" chwidth_suffix="$2" hw_mode="$3" channel="$4" chwidth_extra="$5" variant_name="$6" variant_body="$7" extra="$8"
  local ssid="LAB-${band}-${chwidth_suffix}-${variant_name}"
  write_cfg "$OUT_WIDTHS" "$band" "$hw_mode" "$channel" "$ssid" "${extra}"$'\n'"${variant_body}" "$chwidth_extra"
}

# 2.4 GHz: варианты ширины канала (используем базовый WPA2Ent-CCMP-P1)
gen_widths_24() {
  local band="24" hw_mode="g" channel="${CH_24}" extra=""
  
  # 20 МГц
  gen_variant_width "$band" "20M" "$hw_mode" "$channel" "" "${V2_NAME}" "${V2_BODY}" "$extra"
  
  # 40 МГц (HT40+ для канала 6)
  gen_variant_width "$band" "40M" "$hw_mode" "$channel" "ht_capab=[HT40+]" "${V2_NAME}" "${V2_BODY}" "$extra"
}

# 5 GHz: варианты ширины канала (используем базовый WPA2Ent-CCMP-P1)
gen_widths_5g() {
  local band="5G" hw_mode="a" channel="${CH_5}" extra=$'ieee80211ac=1'
  
  # 20 МГц
  gen_variant_width "$band" "20M" "$hw_mode" "$channel" "" "${V2_NAME}" "${V2_BODY}" "$extra"
  
  # 40 МГц (VHT)
  local chwidth_40=$'ieee80211ac=1\nvht_oper_chwidth=0'
  gen_variant_width "$band" "40M" "$hw_mode" "$channel" "$chwidth_40" "${V2_NAME}" "${V2_BODY}" "$extra"
  
  # 80 МГц (VHT, центральная частота для канала 36)
  local chwidth_80=$'ieee80211ac=1\nvht_oper_chwidth=1\nvht_oper_centr_freq_seg0_idx=42'
  gen_variant_width "$band" "80M" "$hw_mode" "$channel" "$chwidth_80" "${V2_NAME}" "${V2_BODY}" "$extra"
  
  # 80+80 МГц (VHT, два сегмента: 36-48 и 149-161)
  local chwidth_80p80=$'ieee80211ac=1\nvht_oper_chwidth=2\nvht_oper_centr_freq_seg0_idx=42\nvht_oper_centr_freq_seg1_idx=155'
  gen_variant_width "$band" "80p80M" "$hw_mode" "$channel" "$chwidth_80p80" "${V2_NAME}" "${V2_BODY}" "$extra"
  
  # 160 МГц (VHT, центральная частота для канала 36)
  local chwidth_160=$'ieee80211ac=1\nvht_oper_chwidth=2\nvht_oper_centr_freq_seg0_idx=50'
  gen_variant_width "$band" "160M" "$hw_mode" "$channel" "$chwidth_160" "${V2_NAME}" "${V2_BODY}" "$extra"
  
  # 320 МГц (HE/Wi‑Fi 6E)
  local chwidth_320=$'ieee80211ax=1\nhe_oper_chwidth=2\nhe_oper_centr_freq_seg0_idx=1'
  gen_variant_width "$band" "320M" "$hw_mode" "$channel" "$chwidth_320" "${V2_NAME}" "${V2_BODY}" "$extra"
}

# Генерация базовых конфигов безопасности (42 штуки)
gen_all_security "24" "g" "${CH_24}" ""
gen_all_security "5G" "a" "${CH_5}" $'ieee80211ac=1'

# Генерация конфигов для тестирования ширины каналов (8 штук)
gen_widths_24
gen_widths_5g

# ---------- Индекс для стабильных номеров ----------
# Формат: <номер>\t<профиль_файл>\t<ssid>
INDEX_FILE="${OUT}/index.tsv"
i=1
: > "$INDEX_FILE"
ls -1 "$OUT"/*.conf | sort | while IFS= read -r conf; do
  ssid=$(grep "^ssid=" "$conf" | cut -d= -f2)
  profile=$(basename "$conf")
  printf "%02d\t%s\t%s\n" "$i" "$profile" "$ssid" >> "$INDEX_FILE"
  i=$((i + 1))
done

# Гарантия: в generated и channel-widths не должно быть include=
bad=$(grep -l 'include=' "$OUT"/*.conf "$OUT_WIDTHS"/*.conf 2>/dev/null || true)
if [ -n "$bad" ]; then
  echo "ERROR: include= запрещён в generated/channel-widths. Найдено в: $bad" >&2
  exit 1
fi

echo
echo "DONE."
echo "  Базовые конфиги безопасности: $OUT ($(ls -1 "$OUT"/*.conf 2>/dev/null | wc -l | tr -d ' ') шт.)"
echo "  Конфиги ширины каналов: $OUT_WIDTHS ($(ls -1 "$OUT_WIDTHS"/*.conf 2>/dev/null | wc -l | tr -d ' ') шт.)"
