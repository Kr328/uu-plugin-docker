#!/bin/sh

mount -t tmpfs tmpfs /tmp

echo "# Override dns configuration to avoid loopback" > /etc/resolv.conf
echo "nameserver 223.5.5.5" >> /etc/resolv.conf
echo "nameserver 119.29.29.29" >> /etc/resolv.conf

[ ! -d "/persist/uu" ] && cp -r /home/deck/* /persist/

mount --rbind /persist /home/deck || exit 1

# shellcheck disable=SC3045
ulimit -n 4096 || exit 1

exec /home/deck/uu/uuplugin_monitor.sh "$@"
