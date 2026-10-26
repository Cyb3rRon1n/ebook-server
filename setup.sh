#!/usr/bin/env bash
# One-shot setup: writes .env, makes folders, starts everything in the right order.
# Safe to re-run (it keeps your .env and data).
set -euo pipefail
cd "$(dirname "$0")"

die() { echo "ERROR: $*" >&2; exit 1; }
command -v docker >/dev/null || die "Docker is not installed - https://docs.docker.com/engine/install/"
docker compose version >/dev/null 2>&1 || die "Docker Compose v2 is missing (the 'docker compose' plugin)."
docker info >/dev/null 2>&1 || die "Can't talk to Docker. Add yourself to the docker group (then log out/in) or run with sudo."

set_env() { sed -i "s|^$1=.*|$1=$2|" .env; }

if [ ! -f .env ]; then
  cp env.example .env
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  tz=$(timedatectl show -p Timezone --value 2>/dev/null || true)
  set_env PUID "$(id -u)"
  set_env PGID "$(id -g)"
  [ -n "$tz" ] && set_env TZ "$tz"
  [ -n "$ip" ] && set_env BOOKS_URL "http://$ip:8083"
  if [ -t 0 ]; then
    echo "VPN for downloads (WireGuard). Leave blank to skip for now - you can add it to .env later."
    read -rp "  VPN provider [protonvpn]: " p; [ -n "$p" ] && set_env VPN_SERVICE_PROVIDER "$p"
    read -rsp "  WireGuard PrivateKey: " k; echo; [ -n "$k" ] && set_env WIREGUARD_PRIVATE_KEY "$k"
    read -rp "  WireGuard Address [10.2.0.2/32]: " a; [ -n "$a" ] && set_env WIREGUARD_ADDRESSES "$a"
  fi
  echo "Wrote .env"
fi
set -a; . ./.env; set +a

# Create folders as you (not root), so the containers can write to them.
mkdir -p config/calibre-web-automated config/shelfmark config/prowlarr config/qbittorrent config/gluetun \
  "$DATA_DIR"/books/library "$DATA_DIR"/books/audiobooks "$DATA_DIR"/downloads/ebooks

# Shelfmark mounts CWA's app.db as a file. If Docker got there first it made an empty directory - undo that.
db=config/calibre-web-automated/app.db
[ -d "$db" ] && rmdir "$db"

echo "Starting Books (Calibre-Web Automated)..."
docker compose up -d calibre-web-automated
for _ in $(seq 90); do [ -f "$db" ] && break; sleep 2; done
[ -f "$db" ] || die "Books didn't create its database in 3 minutes - check: docker compose logs calibre-web-automated"

services=(calibre-web-automated shelfmark byparr prowlarr)
if [ -n "${WIREGUARD_PRIVATE_KEY:-}" ]; then
  services+=(gluetun qbittorrent)
else
  echo "No VPN key in .env - skipping qBittorrent for now (downloads need it)."
fi
[[ "${COMPOSE_PROFILES:-}" == *audiobooks* ]] && { mkdir -p config/audiobookshelf; services+=(audiobookshelf); }
docker compose up -d "${services[@]}"

host=$(echo "$BOOKS_URL" | sed -E 's|https?://([^:/]+).*|\1|')
cat <<EOF

Done. Open:
  Books        $BOOKS_URL          (first login: admin / admin123 - change it!)
  Get Books    http://$host:8084   (same login as Books)
  Prowlarr     http://$host:9696
  qBittorrent  http://$host:8080   (temporary password: docker logs qbittorrent | grep -i password)

Next: the "First-time setup" steps in README.md.
EOF
