#!/bin/sh
# certbot-dns-scannet — Let's Encrypt DNS-01 via ScanNet API
# https://github.com/enoch85/certbot-dns-scannet
set -eu

# shellcheck source=/dev/null
. /config/.env

# --- ScanNet API config ---
API="https://api.scannet.dk/dns/v2"
AUTH="https://apiauth.dk.team.blue/realms/scannet/protocol/openid-connect/token"
UA="certbot-dns-scannet/1.0"

# --- Derived values ---
ZONE="${DOMAIN#*.}"
CHALLENGE="_acme-challenge.${DOMAIN}"

# --- Safety: domain must be a subdomain (sub.domain.tld = 2+ dots) ---
case "$DOMAIN" in
  *.*.*)  ;;
  *)  echo "ABORT: DOMAIN must be a subdomain (got: ${DOMAIN})" >&2; exit 1 ;;
esac

# --- Get a short-lived OAuth2 token ---
token() {
  curl -sf -X POST "$AUTH" -A "$UA" \
    -d "grant_type=client_credentials&client_id=${SCANNET_CLIENT_ID}&client_secret=${SCANNET_CLIENT_SECRET}&scope=dns" \
    | jq -r '.access_token'
}

# --- Call the ScanNet DNS API ---
api() {
  method="$1"; path="$2"; shift 2
  curl -sf -X "$method" "${API}${path}" \
    -H "Authorization: bearer $(token)" \
    -H "Content-Type: application/json" \
    -A "$UA" "$@"
}

# ============================================================
# AUTH HOOK — called by certbot to create the challenge record
# ============================================================
if [ "${1:-}" = "auth" ]; then

  # Clean up any stale challenge records (exact FQDN + TXT only)
  OLD=$(api GET "/Domains/${ZONE}/Records" \
    | jq -r ".[] | select(.name == \"${CHALLENGE}\" and .type == \"TXT\") | .id")

  for id in $OLD; do
    echo "Removing stale record ${id}" >&2
    api DELETE "/Domains/${ZONE}/Records/${id}" > /dev/null
  done
  [ -n "$OLD" ] && echo "Waiting for stale records to expire..." >&2 && sleep 60

  # Create the new challenge record
  NEW=$(api POST "/Domains/${ZONE}/Records" \
    -d "{\"name\":\"${CHALLENGE}\",\"type\":\"TXT\",\"data\":\"${CERTBOT_VALIDATION}\",\"ttl\":60}" \
    | jq -r '.id')

  echo "$NEW"                                    # stdout → certbot stores as CERTBOT_AUTH_OUTPUT
  echo "Created record ${NEW}, waiting 30s..." >&2
  sleep 30
  exit 0
fi

# ============================================================
# CLEANUP HOOK — called by certbot after validation
# ============================================================
if [ "${1:-}" = "cleanup" ]; then
  api DELETE "/Domains/${ZONE}/Records/${CERTBOT_AUTH_OUTPUT}" > /dev/null || true
  echo "Cleaned up record ${CERTBOT_AUTH_OUTPUT}" >&2
  exit 0
fi

# ============================================================
# MAIN — run certbot with our hooks
# ============================================================
echo "=== certbot-dns-scannet ==="
echo "Domain: ${DOMAIN}"
echo "Zone:   ${ZONE}"
echo ""

mkdir -p /certs

certbot certonly \
  --non-interactive \
  --agree-tos \
  --email "${ACME_EMAIL}" \
  --preferred-challenges dns \
  --manual \
  --manual-auth-hook "$0 auth" \
  --manual-cleanup-hook "$0 cleanup" \
  --cert-name scannet \
  -d "${DOMAIN}"

cp /etc/letsencrypt/live/scannet/fullchain.pem /certs/cert.pem
cp /etc/letsencrypt/live/scannet/privkey.pem   /certs/key.pem

echo ""
echo "=== Done! Certificates written to ./certs/ ==="
