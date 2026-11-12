FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Cloudflare One Client (WARP) + プロキシ用ツール (nc / microsocks)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg dbus iproute2 iputils-ping \
      netcat-openbsd microsocks \
 && curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg \
      | gpg --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ noble main" \
      > /etc/apt/sources.list.d/cloudflare-client.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends cloudflare-warp \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
# Windows 側で CRLF になっても動くように改行を正規化
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD warp-cli --accept-tos status | grep -q "Status update: Connected" || exit 1

ENTRYPOINT ["/entrypoint.sh"]
