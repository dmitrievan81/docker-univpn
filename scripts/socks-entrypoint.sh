#!/bin/sh
set -u

IFACE="${TUN_DEVICE:-cnem_vnic}"
# UniVPN pushes corporate DNS into the VPN netns; gost runs in a sibling
# container (shared netns, separate mount ns) and otherwise uses Docker→host
# DNS (Amnezia fake-IP 198.18.x.x → HTTP 403 for internal sites).
# Space- or comma-separated nameservers for corp.oooslk.ru (order = preference).
VPN_DNS="${VPN_DNS:-192.168.44.123 192.168.44.70}"
VPN_DOMAIN="${VPN_DOMAIN:-corp.oooslk.ru}"

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

pin_vpn_dns() {
  echo "[socks] pinning resolver to VPN DNS ${VPN_DNS} (${VPN_DOMAIN})"
  {
    printf '%s\n' "# Managed by socks-entrypoint.sh — do not use Docker/host DNS (fake-IP leak)"
    old_ifs=$IFS
    IFS=' ,'
    for ns in ${VPN_DNS}; do
      [ -n "${ns}" ] || continue
      printf 'nameserver %s\n' "${ns}"
    done
    IFS=$old_ifs
    printf 'domain %s\n' "${VPN_DOMAIN}"
  } >/etc/resolv.conf
}

# Keep SOCKS alive across VPN reconnects / gost crashes.
while true; do
  pin_vpn_dns
  echo "[socks] starting SOCKS5 on :1080"
  gost -L=socks5://0.0.0.0:1080
  rc=$?
  echo "[socks] gost exited rc=${rc}; restarting in 2s"
  sleep 2
done
