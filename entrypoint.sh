#!/bin/sh -e

getent group qbittorrent >/dev/null || addgroup -g ${PGID} qbittorrent
getent passwd qbittorrent >/dev/null || adduser -S -D -u ${PUID} -G qbittorrent -g qbadmin -s /sbin/nologin qbittorrent

if [ ! -d /torrents/GeoIP ]
then
	mkdir /torrents/GeoIP
fi

wget https://geolite.clash.dev/Country.mmdb -O /torrents/GeoIP/GeoLite2-Country.mmdb

if [ ! -f /config/qBittorrent.conf ]
then
	cp /default/qBittorrent.conf /config/qBittorrent.conf
	chown -R qbittorrent:qbittorrent /downloads
fi

chown -R qbittorrent:qbittorrent /home/qbittorrent

exec su-exec qbittorrent:qbittorrent "$@"
