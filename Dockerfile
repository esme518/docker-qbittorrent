#
# Dockerfile for qbittorrent
#

FROM alpine:3.12 as builder

RUN apk add --update --no-cache \
    boost-dev \
    cmake \
    curl \
    g++ \
    git \
    libressl-dev \
    make \
    qt5-qtbase \
    qt5-qttools-dev \
    tar \
  && rm -rf /tmp/* /var/cache/apk/*

ARG LIBTORRENT_VERSION="RC_1_2"

RUN set -ex \
  && cd /tmp \
  && git clone https://github.com/arvidn/libtorrent.git \
  && cd libtorrent \
#  && git checkout tags/v${LIBTORRENT_VERSION} \
  && git checkout ${LIBTORRENT_VERSION} \
  && cmake -B builddir \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=14 \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
  && cmake --build builddir \
  && cmake --install builddir \
  && ls -al /usr/local/lib64/

ARG QBITTORRENT_VERSION="4.3.4.1"

RUN set -ex \
  && cd /tmp \
  && git clone https://github.com/qbittorrent/qBittorrent.git \
  && cd qBittorrent \
  && git checkout tags/release-${QBITTORRENT_VERSION} \
  && cmake -B builddir \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=14 \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DDBUS=OFF \
        -DGUI=OFF \
        -DQBT_VER_STATUS="" \
        -DSTACKTRACE=OFF \
  && cmake --build builddir \
  && cmake --install builddir \
  && mv /usr/local/lib64/* /usr/local/lib \
  && ls -al /usr/local/bin/ \
  && qbittorrent-nox --help \
  && ldd /usr/local/bin/qbittorrent-nox |cut -d ">" -f 2|grep lib|cut -d "(" -f 1|xargs tar -chvf /qbittorrent.tar \
  && mkdir /qbittorrent-bin \
  && tar -xvf /qbittorrent.tar -C /qbittorrent-bin \
  && cp --parents /usr/local/bin/qbittorrent-nox /qbittorrent-bin

FROM alpine

COPY --from=builder /qbittorrent-bin /

RUN runDeps="$( \
  scanelf --needed --nobanner /usr/lib/libtorrent-* /usr/bin/qbittorrent* \
    | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
    | xargs -r apk info --installed \
    | sort -u \
  )" \
  && apk add --update --no-cache --virtual .run-deps $runDeps \
  && apk add --update --no-cache ca-certificates dumb-init python3 su-exec \
  && rm -rf /tmp/* /var/cache/apk/*

RUN chmod a+x /usr/local/bin/qbittorrent-nox \
  && mkdir -p /home/qbittorrent/.config/qBittorrent \
  && mkdir -p /home/qbittorrent/.local/share/qBittorrent \
  && mkdir /downloads \
  && ln -s /home/qbittorrent/.config/qBittorrent /config \
  && ln -s /home/qbittorrent/.local/share/qBittorrent /torrents

COPY qBittorrent.conf /default/qBittorrent.conf
COPY entrypoint.sh /

VOLUME ["/config", "/torrents", "/downloads"]

ENV HOME=/home/qbittorrent
ENV PUID=1500
ENV PGID=1500
ENV WEBUI_PORT=8080

ENTRYPOINT ["dumb-init", "/entrypoint.sh"]
CMD qbittorrent-nox --webui-port=$WEBUI_PORT
