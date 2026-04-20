FROM alpine:3.23
LABEL org.opencontainers.image.source="https://github.com/enoch85/certbot-dns-scannet"
LABEL org.opencontainers.image.description="Certbot DNS-01 hook for ScanNet domains"
RUN apk add --no-cache certbot curl jq
COPY scannet-dns-hook.sh /usr/local/bin/scannet-dns-hook
RUN chmod +x /usr/local/bin/scannet-dns-hook
ENTRYPOINT ["scannet-dns-hook"]
