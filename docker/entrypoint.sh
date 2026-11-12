#!/bin/bash
set -uo pipefail

warp() { warp-cli --accept-tos "$@"; }

# --- TUN デバイス ---
mkdir -p /dev/net
[ -c /dev/net/tun ] || mknod /dev/net/tun c 10 200
chmod 600 /dev/net/tun

# --- dbus (warp-svc が必要とする) ---
mkdir -p /run/dbus
rm -f /run/dbus/pid
dbus-daemon --system --fork

# --- warp-svc 起動 ---
# (詳細ログは /var/lib/cloudflare-warp/cfwarp_service_log.txt に出力される)
warp-svc --accept-tos >/dev/null 2>&1 &
SVC_PID=$!

for _ in $(seq 1 30); do
  warp status >/dev/null 2>&1 && break
  sleep 1
done

# --- SOCKS5 プロキシ (ホストの 127.0.0.1:${SOCKS_PORT:-1080} に公開される) ---
microsocks -i 0.0.0.0 -p 1080 >/dev/null 2>&1 &

# --- 接続 (登録情報は volume に保存されている) ---
if warp status 2>&1 | grep -qi "registration missing"; then
  echo "[entrypoint] デバイス未登録です。ホストで docker/scripts/00_register.ps1 を実行してください。"
else
  warp connect || true
  sleep 3
  warp status || true
fi

wait "$SVC_PID"
