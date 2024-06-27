#
# Copyright (c) 2020-2024 Robert Scheck <robert@fedoraproject.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#

FROM alpine:latest

LABEL maintainer="Robert Scheck <https://github.com/openbgpd-portable/openbgpd-container>" \
      description="OpenBGPD Routing Daemon" \
      org.opencontainers.image.title="openbgpd" \
      org.opencontainers.image.description="OpenBGPD Routing Daemon" \
      org.opencontainers.image.url="https://www.openbgpd.org/" \
      org.opencontainers.image.documentation="https://man.openbsd.org/bgpd" \
      org.opencontainers.image.source="https://github.com/openbgpd-portable" \
      org.opencontainers.image.licenses="ISC" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.name="openbgpd" \
      org.label-schema.description="OpenBGPD Routing Daemon" \
      org.label-schema.url="https://www.openbgpd.org/" \
      org.label-schema.usage="https://man.openbsd.org/bgpd" \
      org.label-schema.vcs-url="https://github.com/openbgpd-portable"

ARG VERSION=8.5
ARG PORTABLE_GIT
ARG PORTABLE_COMMIT
ARG OPENBSD_GIT
ARG OPENBSD_COMMIT

COPY entrypoint.sh haproxy.cfg healthcheck.sh openbgpd.pub /
RUN set -x && \
  chmod 0755 /entrypoint.sh /healthcheck.sh

RUN set -x && \
  export BUILDREQ="git autoconf automake libtool signify build-base bison libevent-dev libmnl-dev" && \
  apk --no-cache upgrade && \
  apk --no-cache add ${BUILDREQ} haproxy libevent libmnl multirun tzdata && \
  cd /tmp/ && \
  if [ -z "${PORTABLE_GIT}" -a -z "${PORTABLE_COMMIT}" -a -z "${OPENBSD_GIT}" -a -z "${OPENBSD_COMMIT}" ]; then \
    wget "https://ftp.openbsd.org/pub/OpenBSD/OpenBGPD/openbgpd-${VERSION}.tar.gz" && \
    wget https://ftp.openbsd.org/pub/OpenBSD/OpenBGPD/SHA256.sig && \
    signify -C -p /openbgpd.pub -x SHA256.sig "openbgpd-${VERSION}.tar.gz" && \
    tar xfz "openbgpd-${VERSION}.tar.gz" && \
    cd "openbgpd-${VERSION}/"; \
  else \
    git clone -b "${PORTABLE_COMMIT:-master}" --single-branch "${PORTABLE_GIT:-https://github.com/openbgpd-portable/openbgpd-portable.git}" && \
    cd openbgpd-portable/ && \
    git clone -b "${OPENBSD_COMMIT:-master}" --single-branch "${OPENBSD_GIT:-https://github.com/openbgpd-portable/openbgpd-openbsd.git}" openbsd/ && \
    rm -rf openbsd/.git/ && \
    ./autogen.sh; \
  fi && \
  ./configure \
    --prefix=/usr \
    --sysconfdir=/etc/bgpd \
    --runstatedir=/run/bgpd \
    --with-privsep-user=bgpd \
    --with-bgplgd-user=bgplgd \
    --with-www-user=haproxy \
    --with-wwwrunstatedir=/var/lib/haproxy/run && \
  make V=1 && \
  addgroup -g 900 -S bgpd && \
  adduser -h /var/empty/bgpd -g "Privilege-separated BGP" -G bgpd -S -D -u 900 bgpd && \
  addgroup -g 901 -S bgplgd && \
  adduser -h /var/empty/bgpd -g "OpenBGPD Looking Glass" -G bgplgd -S -D -u 901 bgplgd && \
  make install-strip INSTALL='install -p' && \
  chown root:root /var/empty/bgpd/ /var/lib/haproxy/run/ && \
  chmod 0711 /var/empty/bgpd/ /var/lib/haproxy/run/ && \
  sed -e 's|/var/db/rpki-client/openbgpd|/var/lib/rpki-client/openbgpd|' -i /etc/bgpd/bgpd.conf && \
  echo -e '\n# restricted bgpd socket for bgplgd\nsocket "/run/bgpd/bgpd.rsock" restricted' >> /etc/bgpd/bgpd.conf && \
  install -D -m 0644 /dev/null /var/lib/rpki-client/openbgpd && \
  cd .. && \
  rm -rf openbgpd* /openbgpd.pub SHA256.sig && \
  apk --no-cache del ${BUILDREQ} && \
  mv -f /haproxy.cfg /etc/haproxy/haproxy.cfg && \
  bgpd -V

ENV TZ=UTC
VOLUME ["/etc/bgpd/", "/run/bgpd/", "/var/lib/rpki-client/"]
EXPOSE 179 9099

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bgpd", "-d", "-v"]
HEALTHCHECK CMD ["/healthcheck.sh"]
