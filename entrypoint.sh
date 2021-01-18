#!/bin/sh -e

getent group qbittorrent >/dev/null || addgroup -g ${PGID} qbittorrent
getent passwd qbittorrent >/dev/null || adduser -S -D -u ${PUID} -G qbittorrent -g qbadmin -s /sbin/nologin qbittorrent

if [ ! -d /torrents/GeoIP ]
then
	mkdir /torrents/GeoIP
fi

if [ -n "$GEOIP_AUTOUPDATE" ] || [ ! -f /torrents/GeoIP/GeoLite2-Country.mmdb ]
then
	wget -q https://geolite.clash.dev/Country.mmdb -O /torrents/GeoIP/GeoLite2-Country.mmdb
fi

if [ ! -f /config/qBittorrent.conf ]
then
	cp /default/qBittorrent.conf /config/qBittorrent.conf
	chown -R qbittorrent:qbittorrent /downloads
fi

chown -R qbittorrent:qbittorrent /home/qbittorrent

exec su-exec qbittorrent:qbittorrent "$@"
