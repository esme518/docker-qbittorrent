#
# Dockerfile for qbittorrent
#

FROM alpine:3.12 as builder

RUN set -ex \
  && echo "@edge http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories \
  && echo "@edge http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
  && apk add --update --no-cache \
     autoconf \
     automake \
     build-base \
     cmake@edge \
     curl \
     git \
     icu-dev \
     libexecinfo-dev \
     libtool \
     linux-headers \
     openssl-dev@edge \
     perl \
     pkgconf \
     python3 \
     python3-dev \
     qt5-qtbase-dev@edge \
     qt5-qtsvg-dev@edge \
     qt5-qttools-dev@edge \
     re2c \
     tar \
     zlib-dev@edge \
  && rm -rf /tmp/* /var/cache/apk/*

RUN set -ex \
  && cd /tmp \
  && git clone --shallow-submodules --recurse-submodules https://github.com/ninja-build/ninja.git \
  && cd ninja \
  && git checkout "$(git tag -l --sort=-v:refname "v*" | head -n 1)" \
  && cmake -Wno-dev -B build \
       -D CMAKE_CXX_STANDARD=17 \
       -D CMAKE_INSTALL_PREFIX="/usr/local" \
  && cmake --build build \
  && cmake --install build

RUN set -ex \
  && cd /tmp \
  && curl -SNLk "https://boostorg.jfrog.io/artifactory/main/release/1.76.0/source/boost_1_76_0.tar.gz" -o boost.tar.gz \
  && mkdir -p /usr/lib/boost \
  && tar -xf boost.tar.gz -C /usr/lib/boost --strip-components=1 \
  && ls -al /usr/lib/boost/

ARG LIBTORRENT_VERSION="RC_1_2"

RUN set -ex \
  && cd /tmp \
  && git clone --shallow-submodules --recurse-submodules https://github.com/arvidn/libtorrent.git \
  && cd libtorrent \
# && git checkout tags/v${LIBTORRENT_VERSION} \
  && git checkout ${LIBTORRENT_VERSION} \
  && cmake -Wno-dev -G Ninja -B build \
       -D CMAKE_BUILD_TYPE="Release" \
       -D CMAKE_CXX_STANDARD=17 \
       -D BOOST_INCLUDEDIR="/usr/lib/boost/" \
       -D CMAKE_INSTALL_LIBDIR="lib" \
       -D CMAKE_INSTALL_PREFIX="/usr/local" \
  && cmake --build build \
  && cmake --install build \
  && ls -al /usr/local/lib/

ARG QBITTORRENT_VERSION="4.3.6"

RUN set -ex \
  && cd /tmp \
  && git clone --shallow-submodules --recurse-submodules https://github.com/qbittorrent/qBittorrent.git \
  && cd qBittorrent \
  && git checkout tags/release-${QBITTORRENT_VERSION} \
  && cmake -Wno-dev -G Ninja -B build \
       -D CMAKE_BUILD_TYPE="release" \
       -D CMAKE_CXX_STANDARD=17 \
       -D BOOST_INCLUDEDIR="/usr/lib/boost/" \
       -D CMAKE_CXX_STANDARD_LIBRARIES="/usr/lib/libexecinfo.so" \
       -D CMAKE_INSTALL_PREFIX="/usr/local" \
       -D DBUS=OFF \
       -D GUI=OFF \
       -D QBT_VER_STATUS="" \
       -D STACKTRACE=OFF \
  && cmake --build build \
  && cmake --install build \
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
