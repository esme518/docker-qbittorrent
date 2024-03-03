#
# Dockerfile for qbittorrent
#

FROM alpine:3.19 as builder

RUN set -ex \
  && apk add --update --no-cache \
     autoconf \
     automake \
     build-base \
     cmake \
     curl \
     git \
     gnu-libiconv \
     icu-dev \
     libtool \
     linux-headers \
     openssl-dev \
     perl \
     pkgconf \
     python3 \
     python3-dev \
     qt6-qtbase-dev \
     qt6-qtsvg-dev \
     qt6-qttools-dev \
     re2c \
     samurai \
     tar \
     tree \
     zlib-dev \
  && rm -rf /tmp/* /var/cache/apk/*

ARG BOOST_DL="https://www.boost.org/users/download/"
ARG BOOST_REL="https://boostorg.jfrog.io/artifactory/main/release/"

RUN set -ex \
  && cd /tmp \
  && export BOOST_VERSION=$(curl -sS $BOOST_DL | grep current | egrep -o '\"[0-9]\..+\"' | sed -e 's/\///g;s/"//g') \
  && wget -O boost.tar.gz "$BOOST_REL${BOOST_VERSION}/source/boost_${BOOST_VERSION//./_}.tar.gz" \
  && mkdir -p /usr/lib/boost \
  && tar -xf boost.tar.gz -C /usr/lib/boost --strip-components=1 \
  && ls -al /usr/lib/boost/

ARG LIBTORRENT_VERSION="RC_2_0"

RUN set -ex \
  && cd /tmp \
  && git clone --shallow-submodules --recurse-submodules https://github.com/arvidn/libtorrent.git \
  && cd libtorrent \
# && git checkout tags/v${LIBTORRENT_VERSION} \
  && git checkout ${LIBTORRENT_VERSION} \
  && cmake -Wno-dev -G Ninja -B build \
       -D CMAKE_BUILD_TYPE="Release" \
       -D CMAKE_CXX_STANDARD=17 \
       -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
       -D BOOST_INCLUDEDIR="/usr/lib/boost/" \
       -D CMAKE_INSTALL_LIBDIR="lib" \
       -D CMAKE_INSTALL_PREFIX="/usr/local" \
       -D deprecated-functions=OFF \
  && cmake --build build -j $(nproc) \
  && cmake --install build \
  && ls -al /usr/local/lib/

ARG QBITTORRENT_VERSION="4.5.5"

RUN set -ex \
  && cd /tmp \
  && git clone --shallow-submodules --recurse-submodules https://github.com/qbittorrent/qBittorrent.git \
  && cd qBittorrent \
  && git checkout tags/release-${QBITTORRENT_VERSION} \
  && cmake -Wno-dev -G Ninja -B build \
       -D CMAKE_BUILD_TYPE="Release" \
       -D CMAKE_CXX_STANDARD=17 \
       -D CMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
       -D BOOST_INCLUDEDIR="/usr/lib/boost/" \
       -D CMAKE_INSTALL_PREFIX="/usr/local" \
       -D QT6=ON \
       -D DBUS=OFF \
       -D GUI=OFF \
       -D QBT_VER_STATUS="" \
       -D STACKTRACE=OFF \
  && cmake --build build -j $(nproc) \
  && cmake --install build \
  && ls -al /usr/local/bin/ \
  && qbittorrent-nox --help

WORKDIR /build
RUN set -ex \
  && ldd /usr/local/bin/qbittorrent-nox |cut -d ">" -f 2|grep lib|cut -d "(" -f 1|xargs tar -chvf /tmp/qbittorrent.tar \
  && tar -xvf /tmp/qbittorrent.tar -C /build \
  && cp --parents /usr/local/bin/qbittorrent-nox /build \
  && export runDeps="$( \
     scanelf --needed --nobanner usr/local/lib/* usr/local/bin/* \
      | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
      | xargs -r apk info --installed \
      | sort -u \
     )" \
  && echo $runDeps > usr/local/run-deps \
  && tree

FROM alpine:3.19
COPY --from=builder /build/usr/local /usr/local

RUN set -ex \
  && export runDeps="$(cat /usr/local/run-deps)" \
  && apk add --update --no-cache --virtual .run-deps $runDeps \
  && apk add --update --no-cache ca-certificates python3 su-exec tini \
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

ENTRYPOINT ["/sbin/tini", "-g", "--", "/entrypoint.sh"]
CMD qbittorrent-nox --webui-port=$WEBUI_PORT
