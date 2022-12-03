#!/bin/sh
set -e

getent group qbittorrent >/dev/null || addgroup -g ${PGID} qbittorrent
getent passwd qbittorrent >/dev/null || adduser -S -D -u ${PUID} -G qbittorrent -g qbadmin -s /sbin/nologin qbittorrent

if [ ! -f /config/qBittorrent.conf ]
then
	cp /default/qBittorrent.conf /config/qBittorrent.conf
	chown -R qbittorrent:qbittorrent /downloads
fi

chown -R qbittorrent:qbittorrent /home/qbittorrent

exec su-exec qbittorrent:qbittorrent "$@"
