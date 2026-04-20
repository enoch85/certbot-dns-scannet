FROM certbot/certbot:latest
RUN apk add --no-cache curl jq
COPY scannet-dns-hook.sh /usr/local/bin/scannet-dns-hook
RUN chmod +x /usr/local/bin/scannet-dns-hook
ENTRYPOINT ["scannet-dns-hook"]
