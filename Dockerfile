FROM debian:trixie-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG BIND9_REPO=bind

# Build date and revision labels are added by the publish workflow
LABEL maintainer="Daniel Gibbs <me@danielgibbs.co.uk>" \
  org.opencontainers.image.title="BIND 9" \
  org.opencontainers.image.description="BIND 9 DNS server on Debian, using the latest upstream packages from packages.sury.org" \
  org.opencontainers.image.url="https://github.com/dgibbs64/docker-bind9" \
  org.opencontainers.image.source="https://github.com/dgibbs64/docker-bind9" \
  org.opencontainers.image.vendor="dgibbs64" \
  org.opencontainers.image.licenses="MIT"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install BIND 9 from the packages.sury.org repository (maintained by the Debian BIND maintainer)
# hadolint ignore=DL3008
RUN echo "**** Install BIND 9 ****" \
  && apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl \
  && curl -fsSLo /tmp/debsuryorg-archive-keyring.deb https://packages.sury.org/debsuryorg-archive-keyring.deb \
  && dpkg -i /tmp/debsuryorg-archive-keyring.deb \
  && echo "deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/${BIND9_REPO}/ trixie main" > /etc/apt/sources.list.d/bind.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
  bind9 \
  bind9-dnsutils \
  tzdata \
  && apt-get purge -y curl \
  && apt-get -y autoremove \
  && apt-get -y clean \
  && rm -f /etc/bind/rndc.key \
  && mkdir -p /run/named /var/cache/bind /var/lib/bind /var/log/bind \
  && chown bind:bind /run/named /var/cache/bind /var/lib/bind /var/log/bind \
  && dpkg-query -W -f='${Version}\n' bind9 | sed -E 's/^[0-9]+://; s/-.*//' > /etc/bind9-version \
  && rm -rf /usr/share/man /usr/share/doc /usr/share/info /usr/share/lintian /usr/share/locale/* \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy entrypoint
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

VOLUME ["/etc/bind", "/var/cache/bind", "/var/lib/bind"]

EXPOSE 53/udp 53/tcp 853/tcp 953/tcp

# Any answer (including REFUSED) means named is up and serving
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["/bin/bash", "-c", "dig +time=2 +tries=1 @127.0.0.1 . SOA | grep -q 'status:'"]

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["-g"]
