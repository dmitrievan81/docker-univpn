# UniVPN headless + SOCKS5 (variant A)

Headless Huawei/LeagSoft **UniVPN** (`UniVPNCS`) in Docker, with **SOCKS5 on the host** at `127.0.0.1:1080`.  
GUI/VNC are not used. Host apps (e.g. `xfreerdp3`) send traffic through the proxy.

Legacy noVNC stack is kept as `Dockerfile.novnc` / `docker-compose.novnc.yml` / `readme.novnc.md`.

## Architecture

```text
Host: xfreerdp3 /proxy:socks5://127.0.0.1:1080 /v:...
                 │
           TCP 127.0.0.1:1080
                 ▼
┌────────────────────────────────┐
│ univpn (jesusdf/huawei-vpn)    │
│   UniVPNCS → cnem_vnic         │
│ univpn-socks (gost)            │  network_mode: service:univpn
│   SOCKS5 :1080                 │
└────────────────┬───────────────┘
                 ▼
          vpn.oooslk.ru:4443
```

## Prerequisites

- Docker + Compose
- `/dev/net/tun` on the host (`ls -l /dev/net/tun`)
- Gateway accepts **username/password** only (no OTP/certificate) — required for CLI login

## Setup

```bash
cd ~/projects/docker-univpn
cp .env.example .env
# edit .env: VPN_USERNAME / VPN_PASSWORD

docker compose pull
docker compose up -d
docker compose ps
docker compose logs -f univpn
```

Healthy when logs show tunnel established and `cnem_vnic` exists:

```bash
docker compose exec univpn ip -br link
docker compose exec univpn ip route
```

## Use SOCKS5 from the host

Prefer **`--socks5-hostname`** (or browser “proxy DNS”) so names resolve inside the VPN, not on the host (Amnezia fake-IP `198.18.x.x` → HTTP 403).

```bash
# Internet check
curl -sS --socks5-hostname 127.0.0.1:1080 https://ifconfig.me; echo

# Internal GitLab
curl -sS -k --socks5-hostname 127.0.0.1:1080 -o /dev/null -w '%{http_code}\n' https://gitlab.oooslk.ru/users/sign_in

# RDP
xfreerdp3 /proxy:socks5://127.0.0.1:1080 /v:INTERNAL_HOST:3389 /u:USER
```

Firefox: SOCKS5 `127.0.0.1:1080` + remote DNS (`network.proxy.socks_remote_dns=true`).

## Stop

```bash
docker compose down
```

## Notes

- SOCKS is bound to **127.0.0.1** only (not exposed to LAN).
- Split tunnelling: only routes pushed by the gateway go via VPN; use an internal IP/hostname reachable through those routes for RDP.
- `scripts/connect.exp` is mounted over the image script so passwords that start with `-` work (`send --`).
- `socks-entrypoint.sh` pins `/etc/resolv.conf` to UniVPN DNS (`192.168.44.123`, `192.168.44.70` for `corp.oooslk.ru`) so gost does not leak to host Amnezia DNS.
- Image: [jesusdf/huawei-vpn](https://hub.docker.com/r/jesusdf/huawei-vpn) (official UniVPN CLI + expect). SOCKS: [ginuerzh/gost](https://hub.docker.com/r/ginuerzh/gost).
