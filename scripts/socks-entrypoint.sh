#!/bin/sh
set -u

IFACE="${TUN_DEVICE:-cnem_vnic}"
echo "[socks] waiting for ${IFACE} ..."
i=0
while [ ! -e "/sys/class/net/${IFACE}" ]; do
  i=$((i + 1))
  if [ "${i}" -gt 90 ]; then
    echo "[socks] timeout waiting for ${IFACE} — starting SOCKS anyway"
    break
  fi
  sleep 2
done

if [ -e "/sys/class/net/${IFACE}" ]; then
  echo "[socks] ${IFACE} is up"
fi

# Keep SOCKS alive across VPN reconnects / gost crashes (exit 2 with no log).
while true; do
  echo "[socks] starting SOCKS5 on :1080"
  gost -L=socks5://0.0.0.0:1080
  rc=$?
  echo "[socks] gost exited rc=${rc}; restarting in 2s"
  sleep 2
done
