# certbot-dns-scannet

Let's Encrypt certificates via DNS-01 challenge for domains hosted on [ScanNet](https://www.scannet.dk) (part of [team.blue](https://team.blue)).

ScanNet isn't supported by certbot or [lego](https://go-acme.github.io/lego/dns/) out of the box. This project fills that gap with a lightweight Docker container that handles issuance, renewal, and cleanup automatically via ScanNet's REST API.

## Features

- Fully automated DNS-01 challenge — no HTTP server or inbound access needed
- Works for internal/private servers not reachable from the internet
- Automatic cleanup of challenge TXT records after validation
- Safety guards: refuses to run on bare domains, only touches `_acme-challenge` TXT records
- Persists Let's Encrypt state between runs for proper renewal tracking
- Runs as a one-shot container — no daemon, no cron inside the container

## Prerequisites

- A domain hosted on ScanNet's DNS (DNS Hotel, Webhotel, etc.)
- ScanNet API credentials (see [Setup](#setup))
- Docker and Docker Compose

## Setup

### 1. Create ScanNet API credentials

1. Log in at [controlpanel.scannet.dk](https://controlpanel.scannet.dk)
2. Go to **Min konto → API applikationer**
3. Create a new application with **DNS** access enabled
4. Note the `client_id` and `client_secret`

API docs: [api.scannet.dk/dns/swagger](https://api.scannet.dk/dns/swagger/index.html?urls.primaryName=Dns%20API%20v2)

### 2. Configure

```bash
cp .env.example .env
```

Edit `.env` with your values:

```env
DOMAIN=sub.example.dk
ACME_EMAIL=you@example.dk
SCANNET_CLIENT_ID=your-client-id
SCANNET_CLIENT_SECRET=your-client-secret
```

### 3. Get your certificate

```bash
docker compose run --rm certbot
```

Certificates are written to `./certs/`:

```
certs/
├── cert.pem      # Full chain (cert + intermediate)
└── key.pem       # Private key
```

### 4. Set up auto-renewal

Certbot only renews if the certificate expires within 30 days.

```bash
# crontab -e
0 3 1 * * cd /path/to/certbot-dns-scannet && docker compose run --rm certbot >> /var/log/certbot-scannet.log 2>&1
```

## Usage with a reverse proxy

### Traefik

```yaml
# traefik command
- "--providers.file.filename=/etc/traefik/tls.yml"
- "--providers.file.watch=true"

# traefik volumes
- ./certs:/certs:ro
- ./tls.yml:/etc/traefik/tls.yml:ro
```

`tls.yml`:
```yaml
tls:
  certificates:
    - certFile: /certs/cert.pem
      keyFile: /certs/key.pem
```

### nginx

```nginx
ssl_certificate     /path/to/certs/cert.pem;
ssl_certificate_key /path/to/certs/key.pem;
```

### Caddy

```
tls /certs/cert.pem /certs/key.pem
```

## How it works

1. Authenticates with ScanNet's OAuth2 endpoint (`apiauth.dk.team.blue`)
2. Deletes any stale `_acme-challenge` TXT records for the domain
3. Creates a new TXT record with the ACME challenge token
4. Waits for DNS propagation
5. Let's Encrypt verifies the record and issues the certificate
6. Cleans up the challenge TXT record
7. Copies the certificate to `./certs/`

The script only ever creates/deletes records matching **exactly** `_acme-challenge.<your-domain>` with type `TXT`. It will refuse to run if the domain doesn't have a subdomain (safety against accidentally modifying zone-level records).

## ScanNet API reference

| | |
|---|---|
| **Base URL** | `https://api.scannet.dk/dns/v2` |
| **Auth** | OAuth2 client_credentials via `https://apiauth.dk.team.blue/realms/scannet/protocol/openid-connect/token` |
| **Token TTL** | 5 minutes |
| **Docs** | [Swagger UI](https://api.scannet.dk/dns/swagger/index.html?urls.primaryName=Dns%20API%20v2) |

All requests require a `User-Agent` header.

## License

MIT
