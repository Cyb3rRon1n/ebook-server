# ebook-server

Your own ebook library with **Send to Kindle**: a replacement for Kindle Unlimited that works with stock Kindles.

| | App | What people do there |
|---|---|---|
| 📚 **Books** | [Calibre-Web Automated](https://github.com/crocodilestick/Calibre-Web-Automated) | Browse the library, read online, tap **Send to eReader** to email a book to their Kindle |
| 🔎 **Get Books** | [Shelfmark](https://github.com/calibrain/shelfmark) | Search for a book that isn't in the library and request it. It downloads and appears in Books automatically |

Behind the scenes: **Prowlarr** (indexers), **qBittorrent** (downloads, only through a VPN via **gluetun**), **byparr** (gets past Cloudflare checks). **Audiobookshelf** is optional.

Both sites use one login: the Books account.

## Install

You need a Linux machine (or WSL2) with [Docker](https://docs.docker.com/engine/install/) and a WireGuard VPN account for downloads. Proton VPN, Mullvad and others work; see the [gluetun provider list](https://github.com/qdm12/gluetun-wiki).

```bash
git clone https://github.com/Cyb3rRon1n/ebook-server.git
cd ebook-server
./setup.sh
```

`setup.sh` asks for your VPN's WireGuard key, writes `.env`, creates the folders and starts everything in the right order. You can leave the VPN blank to try it out first. Everything except downloads will work, and you can add the key to `.env` and re-run `./setup.sh` later.

Settings (data folder, timezone, VPN, audiobooks) are in `.env`. Re-run `./setup.sh` after changing them.

**Update:** `docker compose pull && docker compose up -d`

## First-time setup (admin, about 15 minutes)

**1. Books** (`http://<host>:8083`)
- Log in as `admin` / `admin123`, then **change the password** (top right → your name).
- **Admin → Edit Mail Server Settings**: this is the address that sends books to Kindles. For Gmail use `smtp.gmail.com`, port `587`, STARTTLS, your Gmail address, and an [app password](https://myaccount.google.com/apppasswords).
- **Admin → Add new user** for each person. Get Books uses the same accounts.

**2. qBittorrent** (`http://<host>:8080`)
- Username `admin`. Get the temporary password with `docker logs qbittorrent | grep -i password`.
- **Settings → WebUI**: set your own password.
- **Settings → Downloads → Default Save Path**: `/data/downloads`

**3. Prowlarr** (`http://<host>:9696`)
- Set a login when it asks.
- **Settings → Indexers → Add (+) → FlareSolverr**: host `http://byparr:8191`, tag `cloudflare`.
- **Indexers → Add Indexer**: add the book/general indexers you want. If an indexer test fails with "Cloudflare protection", give that indexer the `cloudflare` tag.
- **Settings → General**: copy the **API Key**.

**4. Get Books** (`http://<host>:8084`, log in with your Books admin account)
- **Settings → Prowlarr**: URL `http://prowlarr:9696` plus the API key.
- **Settings → qBittorrent**: URL `http://gluetun:8080` plus your qBittorrent login.
- Turn **Direct Download** off. Its main source is behind DDoS protection and fails.
- Optional: a free [Hardcover](https://hardcover.app) API key under Metadata gives better search results.

Test it: request a book in Get Books. A few minutes later it shows up in Books.

## For your readers (one-time, about 5 minutes)

1. **Find your Kindle's email:** amazon.com → Account → **Content Library → Devices** → your Kindle (looks like `name_abc123@kindle.com`).
2. **Allow the server to send to it:** Amazon → **Preferences → Personal Document Settings → Approved Personal Document E-mail List → Add** the sender address the admin set in step 1.
3. **Books** → your name (top right) → **Send to eReader Email Address** → paste the `@kindle.com` address → Save.

From then on: open a book in Books → **Send to eReader** → turn on the Kindle's Wi-Fi. The book also appears in the Kindle phone app.

To request a book: **Get Books** → search → **Request**. An admin approves it, and it appears in Books.

Free extras: **Libby** (needs a library card; "Read With Kindle") and **Prime Reading** (if you have Prime).

## Good to know

- **Don't put your real book collection in `data/downloads/ebooks`.** Books imports files from there and then **deletes** them. To add books you already own, drop *copies* there.
- Using it away from home: put Books (8083) and Get Books (8084) behind a reverse proxy or Cloudflare Tunnel with HTTPS, then set `HTTPS=true` and `BOOKS_URL=https://...` in `.env` and re-run `./setup.sh`. Leave `HTTPS=false` on plain http, or the Get Books login breaks.
- qBittorrent only runs through the VPN. If the VPN is down, downloads stop instead of leaking. Check with `docker compose logs gluetun`.
- A book didn't reach the Kindle? Check that the Kindle address in Books is right and that the sender is on Amazon's approved list. Amazon emails you when it rejects a file.
