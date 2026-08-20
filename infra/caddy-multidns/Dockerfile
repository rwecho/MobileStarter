# Caddy with forwardproxy + DNS providers (alidns/tencentcloud/cloudflare)
# Multi-arch build via GitHub Actions (amd64 + arm64)

FROM caddy:builder AS build
ENV GOPROXY=https://goproxy.cn,direct
RUN xcaddy build \
    --with github.com/caddyserver/forwardproxy \
    --with github.com/caddy-dns/alidns \
    --with github.com/caddy-dns/tencentcloud \
    --with github.com/caddy-dns/cloudflare

FROM caddy:latest
COPY --from=build /usr/bin/caddy /usr/bin/caddy