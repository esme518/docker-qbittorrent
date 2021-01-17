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
    libcap \
    make \
    openssl-dev \
    qt5-qtbase \
    qt5-qttools-dev \
    tar \
  && rm -rf /tmp/* /var/cache/apk/*

ARG LIBTORRENT_VERSION="1.2.12"

RUN cd /tmp \
  && git clone https://github.com/arvidn/libtorrent.git \
  && cd libtorrent \
  && git checkout tags/v${LIBTORRENT_VERSION} \
  && cmake -B builddir \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_INSTALL_PREFIX:PATH=/usr \
        -DCMAKE_INSTALL_LIBDIR=lib && \
  && cmake --build builddir --parallel $((`nproc`+1)) && \
  && cmake --install builddir && \
  && ls -al /usr/local/lib/

ARG QBITTORRENT_VERSION="4.2.5"

RUN cd /tmp \
  && git clone https://github.com/qbittorrent/qBittorrent.git \
  && cd qBittorrent \
  && git checkout tags/release-${QBITTORRENT_VERSION} \
  && cmake -B builddir \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_INSTALL_PREFIX:PATH=/usr \
        -DSTACKTRACE=OFF \
        -DQBT_VER_STATUS="" \
        -DDBUS=OFF -DGUI=OFF && \
  && cmake --build builddir --parallel $((`nproc`+1)) && \
  && cmake --install builddir && \
  && setcap 'cap_net_bind_service=+ep' /usr/bin/qbittorrent-nox && \
  && ls -al /usr/local/bin/ \
  && qbittorrent-nox --help \
  && ldd /usr/local/bin/qbittorrent-nox |cut -d ">" -f 2|grep lib|cut -d "(" -f 1|xargs tar -chvf /qbittorrent.tar \
  && mkdir /qbittorrent-bin \
  && tar -xvf /qbittorrent.tar -C /qbittorrent-bin \
  && cp --parents /usr/local/bin/qbittorrent-nox /qbittorrent-bin

FROM alpine:3.12

COPY --from=builder /qbittorrent-bin /

RUN runDeps="$( \
  scanelf --needed --nobanner /usr/lib/libtorrent-* /usr/bin/qbittorrent* \
    | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
    | xargs -r apk info --installed \
    | sort -u \
  )" \
  && apk add --update --no-cache --virtual .run-deps $runDeps \
  && apk add --update --no-cache ca-certificates dumb-init su-exec \
  && rm -rf /tmp/* /var/cache/apk/*

RUN chmod a+x /usr/local/bin/qbittorrent-nox \
  && mkdir -p /home/qbittorrent/.config/qBittorrent \
  && mkdir -p /home/qbittorrent/.local/share/data/qBittorrent \
  && mkdir /downloads \
  && ln -s /home/qbittorrent/.config/qBittorrent /config \
  && ln -s /home/qbittorrent/.local/share/data/qBittorrent /torrents

COPY qBittorrent.conf /default/qBittorrent.conf
COPY entrypoint.sh /

VOLUME ["/config", "/torrents", "/downloads"]

ENV HOME=/home/qbittorrent
ENV PUID=1500
ENV PGID=1500
ENV WEBUI_PORT=8080

ENTRYPOINT ["dumb-init", "/entrypoint.sh"]
CMD qbittorrent-nox --webui-port=$WEBUI_PORT
