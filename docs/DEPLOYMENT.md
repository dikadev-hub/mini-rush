# DEPLOYMENT — Mini Rush (VPS)

## Binary server
```bash
bash scripts/build_server.sh   # → build/server/MiniRushServer.x86_64, verifikasi --version
```

## Jaringan
- Server ENet memakai **UDP 7777** (dapat dikonfigurasi via `--port=` atau `MINI_RUSH_PORT`).
- VPS tidak selalu punya IPv4 publik:
  - Jika ada IPv4 publik: buka UDP 7777 langsung.
  - Jika hanya IPv6: client harus mencapai server lewat IPv6 (AAAA record) atau
    tunnel (mis. WireGuard/Tailscale) dengan endpoint IPv4 — jelaskan pilihan ini
    di deployment nyata, jangan diasumsikan.
- Firewall host: `ufw allow 7777/udp`.
- Juga izinkan UDP 7777 di security group / firewall penyedia VPS.

## Docker
`server/Dockerfile` + `server/docker-compose.yml` (spec 9):
- Copy `build/server/` ke image, entrypoint `MiniRushServer.x86_64 --headless -- --server`.
- Konfigurasi via `.env` (salin `server/.env.example` → `server/.env`):
  `MINI_RUSH_PORT`, `MINI_RUSH_MAX_ROOMS`, `MINI_RUSH_MAX_PLAYERS_PER_ROOM`,
  `MINI_RUSH_LOG_LEVEL`, `MINI_RUSH_MATCH_TIMEOUT_SEC`.
- Jangan hardcode kredensial; semua lewat `.env`.
- `docker stop` mengirim SIGTERM → server shutdown rapi (notify room, spec 5.6).

## Verifikasi sebelum dianggap selesai
1. Container jalan lokal: `docker compose -f server/docker-compose.yml up`.
2. Client bisa connect ke host:port.
3. Log health muncul tiap 10 detik di `logs/server.log`.
