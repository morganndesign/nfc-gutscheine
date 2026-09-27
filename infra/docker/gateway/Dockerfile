# ---------------------------------------------------------------------------
# GiftCard Pro gateway — Caddy as internal HTTP router (see Caddyfile).
# Built from source by Coolify; no registry involved.
# ---------------------------------------------------------------------------
FROM caddy:2-alpine
COPY Caddyfile /etc/caddy/Caddyfile
RUN caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
EXPOSE 80
HEALTHCHECK --interval=15s --timeout=5s --retries=3 CMD wget -qO- http://127.0.0.1/gateway-health >/dev/null || exit 1
