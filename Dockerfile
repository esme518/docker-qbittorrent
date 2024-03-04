#
# Dockerfile for qbittorrent
#

FROM alpine as source

WORKDIR /root

RUN set -ex \
    && apk add --update --no-cache git \
    && export tag=$(git ls-remote --tags https://github.com/userdocs/qbittorrent-nox-static.git 'refs/tags/release-4.5*_v2*' | awk -F/ '{ print $3 }' | sort -V | tail -1) \
    && wget -qO qbittorrent-nox https://github.com/userdocs/qbittorrent-nox-static/releases/download/$tag/$(uname -m)-qbittorrent-nox \
    && chmod +x qbittorrent-nox \
    && ./qbittorrent-nox -v

FROM alpine
COPY --from=source /root/qbittorrent-nox /usr/local/bin/qbittorrent-nox

RUN set -ex \
  && apk add --update --no-cache ca-certificates python3 su-exec tini mktorrent \
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

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
CMD qbittorrent-nox --webui-port=$WEBUI_PORT
