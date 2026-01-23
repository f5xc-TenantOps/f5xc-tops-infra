FROM alpine:3.19

RUN apk add --no-cache tor curl

COPY torrc /etc/tor/torrc

RUN mkdir -p /var/lib/tor && \
    chown -R tor:tor /var/lib/tor

USER tor

EXPOSE 9050

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -sf --socks5 localhost:9050 https://check.torproject.org/api/ip | grep -q IsTor || exit 1

CMD ["tor", "-f", "/etc/tor/torrc"]
