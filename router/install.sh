#!/bin/sh
# ============================================================================
#  NITOS — VPN на роутере одной командой (БЕТА)
#  Поддержка: OpenWRT 23.05+ / Keenetic с Entware
#
#  Установка:
#    curl -fsSL https://raw.githubusercontent.com/Heekuez/nitos-releases/main/router/install.sh | sh -s -- "ССЫЛКА"
#  где ССЫЛКА — vless:// конфиг или https:// подписка.
#
#  Удаление:
#    ... | sh -s -- --uninstall
#
#  Что делает: ставит движок sing-box, строит конфиг из вашей ссылки,
#  поднимает TUN-туннель и заворачивает в него трафик всей домашней сети.
# ============================================================================
set -e

say()  { printf '\033[1;36m[NITOS]\033[0m %s\n' "$1"; }
die()  { printf '\033[1;31m[NITOS] ОШИБКА:\033[0m %s\n' "$1" >&2; exit 1; }

LINK="$1"

# ── определяем платформу ────────────────────────────────────────────────────
if [ -f /etc/openwrt_release ]; then
  MODE=openwrt
  CONF_DIR=/etc/sing-box
  SB_BIN=/usr/bin/sing-box
elif [ -x /opt/bin/opkg ]; then
  MODE=entware   # Keenetic и др. с Entware
  CONF_DIR=/opt/etc/sing-box
  SB_BIN=/opt/sbin/sing-box
  PATH="/opt/bin:/opt/sbin:$PATH"
else
  die "не найден opkg. Нужен OpenWRT или Keenetic с установленным Entware.
  Entware на Keenetic: Управление → Приложения → OPKG (нужна USB-флешка)."
fi
say "платформа: $MODE"

# ── удаление ────────────────────────────────────────────────────────────────
if [ "$LINK" = "--uninstall" ]; then
  say "удаляю NITOS с роутера…"
  if [ "$MODE" = openwrt ]; then
    /etc/init.d/sing-box stop 2>/dev/null || true
    /etc/init.d/sing-box disable 2>/dev/null || true
    uci -q delete firewall.nitos && uci -q delete firewall.nitos_fwd && uci commit firewall || true
    /etc/init.d/firewall restart >/dev/null 2>&1 || true
  else
    /opt/etc/init.d/S99sing-box stop 2>/dev/null || true
    [ -f /opt/etc/init.d/S99nitos ] && { /opt/etc/init.d/S99nitos stop 2>/dev/null; rm -f /opt/etc/init.d/S99nitos; } || true
  fi
  rm -rf "$CONF_DIR"
  say "готово. Пакет sing-box можно снести вручную: opkg remove sing-box"
  exit 0
fi

# ── ссылка ──────────────────────────────────────────────────────────────────
if [ -z "$LINK" ]; then
  printf '[NITOS] Вставьте ссылку (vless:// или https://подписка): '
  read -r LINK </dev/tty || die "ссылка не задана. Использование: sh -s -- \"ССЫЛКА\""
fi
[ -n "$LINK" ] || die "пустая ссылка"

# ── ставим sing-box ─────────────────────────────────────────────────────────
say "ставлю движок sing-box…"
opkg update >/dev/null 2>&1 || say "opkg update не прошёл (продолжаю)"
if [ "$MODE" = openwrt ]; then
  opkg install sing-box kmod-tun >/dev/null 2>&1 || true
else
  opkg install sing-box >/dev/null 2>&1 || true
fi

# фолбэк: пакета нет/старый → статический бинарь с GitHub
sb_ver() { "$SB_BIN" version 2>/dev/null | sed -n 's/^sing-box version \([0-9.]*\).*/\1/p'; }
need_dl=0
if [ ! -x "$SB_BIN" ]; then
  need_dl=1
else
  V=$(sb_ver); MAJ=${V%%.*}; MIN=$(echo "$V" | cut -d. -f2)
  # нужна схема конфига 1.12+
  [ "${MAJ:-0}" -gt 1 ] 2>/dev/null || [ "${MIN:-0}" -ge 12 ] 2>/dev/null || need_dl=1
fi
if [ "$need_dl" = 1 ]; then
  say "пакет недоступен или старый — качаю статический sing-box…"
  case "$(uname -m)" in
    aarch64|arm64) A=arm64 ;;
    armv7l|armv7)  A=armv7 ;;
    mips)          A=mips ;;
    mipsel|mipsle) A=mipsle ;;
    x86_64)        A=amd64 ;;
    *) die "неизвестная архитектура: $(uname -m)" ;;
  esac
  TAG=$( (curl -fsSL https://api.github.com/repos/SagerNet/sing-box/releases/latest 2>/dev/null || wget -qO- https://api.github.com/repos/SagerNet/sing-box/releases/latest) | sed -n 's/.*"tag_name": *"\(v[^"]*\)".*/\1/p' | head -1)
  [ -n "$TAG" ] || die "не достучаться до GitHub за sing-box"
  VER=${TAG#v}
  URL="https://github.com/SagerNet/sing-box/releases/download/$TAG/sing-box-$VER-linux-$A.tar.gz"
  TMP=/tmp/nitos-sb.tar.gz
  (curl -fsSL -o "$TMP" "$URL" || wget -qO "$TMP" "$URL") || die "не скачать $URL"
  tar -xzf "$TMP" -C /tmp
  mkdir -p "$(dirname "$SB_BIN")"
  cp "/tmp/sing-box-$VER-linux-$A/sing-box" "$SB_BIN"
  chmod +x "$SB_BIN"
  rm -rf "$TMP" "/tmp/sing-box-$VER-linux-$A"
fi
say "sing-box: $(sb_ver)"

# ── достаём vless-ссылку ────────────────────────────────────────────────────
case "$LINK" in
  http*)
    say "загружаю подписку…"
    HW=$(cat /sys/class/net/eth0/address 2>/dev/null | tr -d ':' || echo router)
    fetch() { curl -fsSL -A "Happ/1.16.0" -H "x-hwid: router-$HW" -H "x-device-os: Router" -H "x-ver-os: 1" -H "x-device-model: $(uname -m)" "$1" 2>/dev/null || wget -qO- --header="User-Agent: Happ/1.16.0" --header="x-hwid: router-$HW" --header="x-device-os: Router" --header="x-ver-os: 1" "$1"; }
    RAW=$(fetch "$LINK") || die "подписка не загрузилась"
    case "$RAW" in
      *vless://*) LIST="$RAW" ;;
      *) LIST=$(echo "$RAW" | base64 -d 2>/dev/null) || die "не разобрать ответ подписки" ;;
    esac
    URI=$(echo "$LIST" | tr -d '\r' | grep -m1 '^vless://') || die "в подписке нет vless-серверов"
    ;;
  vless://*) URI="$LINK" ;;
  *) die "поддерживаются vless:// или https://подписка" ;;
esac

# ── разбор vless://uuid@host:port?params#name ───────────────────────────────
rest=${URI#vless://}; rest=${rest%%#*}
UUID=${rest%%@*}
hp_q=${rest#*@}
hostport=${hp_q%%\?*}
query=${hp_q#*\?}; [ "$query" = "$hp_q" ] && query=""
HOST=${hostport%%:*}
PORT=${hostport##*:}
qv() { echo "$query" | tr '&' '\n' | sed -n "s/^$1=//p" | head -1; }
SEC=$(qv security); SNI=$(qv sni); PBK=$(qv pbk); SID=$(qv sid)
FLOW=$(qv flow); FP=$(qv fp); [ -n "$FP" ] || FP=chrome
[ -n "$UUID" ] && [ -n "$HOST" ] && [ -n "$PORT" ] || die "не разобрать vless-ссылку"
say "сервер: $HOST:$PORT ($SEC)"

# ── TLS-блок ────────────────────────────────────────────────────────────────
if [ "$SEC" = "reality" ]; then
  TLS='"tls":{"enabled":true,"server_name":"'$SNI'","utls":{"enabled":true,"fingerprint":"'$FP'"},"reality":{"enabled":true,"public_key":"'$PBK'","short_id":"'$SID'"}}'
elif [ "$SEC" = "tls" ]; then
  [ -n "$SNI" ] || SNI=$HOST
  TLS='"tls":{"enabled":true,"server_name":"'$SNI'","utls":{"enabled":true,"fingerprint":"'$FP'"}}'
else
  TLS=""
fi
FLOWJ=""; [ -n "$FLOW" ] && [ -n "$SEC" ] && FLOWJ='"flow":"'$FLOW'",'

# ── конфиг ──────────────────────────────────────────────────────────────────
mkdir -p "$CONF_DIR"
cat > "$CONF_DIR/config.json" <<EOF
{
  "log": {"level": "warn"},
  "dns": {
    "servers": [{"type": "udp", "tag": "local", "server": "1.1.1.1", "detour": "direct"}],
    "final": "local"
  },
  "inbounds": [{
    "type": "tun", "tag": "tun-in", "interface_name": "nitos0",
    "address": ["172.19.0.1/30"], "mtu": 1500,
    "auto_route": true, "strict_route": false, "stack": "system"
  }],
  "outbounds": [
    {"type": "vless", "tag": "proxy", "server": "$HOST", "server_port": $PORT,
     "uuid": "$UUID", $FLOWJ $TLS},
    {"type": "direct", "tag": "direct"}
  ],
  "route": {
    "default_domain_resolver": {"server": "local"},
    "auto_detect_interface": true,
    "rules": [
      {"action": "sniff"},
      {"protocol": "dns", "action": "hijack-dns"},
      {"ip_is_private": true, "outbound": "direct"}
    ],
    "final": "proxy"
  }
}
EOF
"$SB_BIN" check -c "$CONF_DIR/config.json" || die "конфиг не прошёл проверку (лог выше)"
say "конфиг собран и проверен"

# ── сервис + фаервол ────────────────────────────────────────────────────────
if [ "$MODE" = openwrt ]; then
  # пакетный init читает uci; при статическом бинаре пути совпадают
  if [ -f /etc/init.d/sing-box ]; then
    uci -q set sing-box.main.enabled='1'
    uci -q set sing-box.main.user='root'
    uci -q set sing-box.main.conffile="$CONF_DIR/config.json"
    uci commit sing-box 2>/dev/null || true
    /etc/init.d/sing-box enable
    /etc/init.d/sing-box restart
  else
    # свой минимальный procd-init (если ставили статический бинарь без пакета)
    cat > /etc/init.d/sing-box <<'INIT'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1
start_service() {
  procd_open_instance
  procd_set_param command /usr/bin/sing-box run -c /etc/sing-box/config.json
  procd_set_param respawn
  procd_close_instance
}
INIT
    chmod +x /etc/init.d/sing-box
    /etc/init.d/sing-box enable
    /etc/init.d/sing-box restart
  fi
  # зона фаервола для туннеля + форвардинг из LAN
  uci -q delete firewall.nitos || true
  uci set firewall.nitos=zone
  uci set firewall.nitos.name='nitos'
  uci set firewall.nitos.device='nitos0'
  uci set firewall.nitos.input='ACCEPT'
  uci set firewall.nitos.output='ACCEPT'
  uci set firewall.nitos.forward='REJECT'
  uci set firewall.nitos.masq='1'
  uci set firewall.nitos.mtu_fix='1'
  uci -q delete firewall.nitos_fwd || true
  uci set firewall.nitos_fwd=forwarding
  uci set firewall.nitos_fwd.src='lan'
  uci set firewall.nitos_fwd.dest='nitos'
  uci commit firewall
  /etc/init.d/firewall restart >/dev/null 2>&1
else
  # Entware: пакетный S99sing-box или свой init
  if [ -f /opt/etc/init.d/S99sing-box ]; then
    ln -sf "$CONF_DIR/config.json" /opt/etc/sing-box/config.json 2>/dev/null || true
    /opt/etc/init.d/S99sing-box restart
  else
    cat > /opt/etc/init.d/S99nitos <<INIT
#!/bin/sh
case "\$1" in
  start) $SB_BIN run -c $CONF_DIR/config.json >/opt/var/log/nitos.log 2>&1 & ;;
  stop)  killall sing-box 2>/dev/null ;;
  restart) \$0 stop; sleep 1; \$0 start ;;
esac
INIT
    chmod +x /opt/etc/init.d/S99nitos
    /opt/etc/init.d/S99nitos restart
  fi
fi

# ── проверка ────────────────────────────────────────────────────────────────
say "проверяю туннель…"
sleep 3
if ! pgrep -f sing-box >/dev/null 2>&1 && ! pidof sing-box >/dev/null 2>&1; then
  die "движок не запустился. Лог: logread | grep sing-box (OpenWRT) или /opt/var/log/nitos.log"
fi
IP=$( (curl -m 8 -fsSL https://api.ipify.org 2>/dev/null || wget -qO- -T 8 https://api.ipify.org 2>/dev/null) || echo "?")
say "туннель поднят. Внешний IP роутера: $IP"
say "готово! Вся домашняя сеть теперь идёт через NITOS."
say "удаление: тот же скрипт с аргументом --uninstall"
