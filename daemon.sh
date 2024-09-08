#!/bin/bash

PERSIST_ROOT=/usr/lib/scoped-uuplugin
RUNTIME_ROOT=/var/run/scoped-uuplugin

function assert() {
    if ! "$@"; then
        echo "Command: $* failed"
        exit 1
    fi
}

assert mkdir -p "$RUNTIME_ROOT"
assert mkdir -p "$PERSIST_ROOT"

# prepare namespace
if [ -z "$__UU_UNSAHRED" ];then
    umount "$RUNTIME_ROOT/network.ns"
    assert touch "$RUNTIME_ROOT/network.ns"
    __UU_UNSAHRED=1 assert exec unshare --mount --net="$RUNTIME_ROOT/network.ns" bash "$0" "$@"
fi

# prepare root
if [ -z "$__UU_CHROOTED" ];then
    assert mkdir -p "$PERSIST_ROOT/data" "$PERSIST_ROOT/work" "$RUNTIME_ROOT/root"
    assert mount -t overlay -o "lowerdir=/,upperdir=$PERSIST_ROOT/data,workdir=$PERSIST_ROOT/work" overlay "$RUNTIME_ROOT/root"
    mountpoint /dev 1>/dev/null 2>&1 && assert mount --rbind /dev "$RUNTIME_ROOT/root/dev"
    mountpoint /proc 1>/dev/null 2>&1 && assert mount --rbind /proc "$RUNTIME_ROOT/root/proc"
    mountpoint /sys 1>/dev/null 2>&1 && assert mount --rbind /sys "$RUNTIME_ROOT/root/sys"
    mountpoint /tmp 1>/dev/null 2>&1 && assert mount --rbind /tmp "$RUNTIME_ROOT/root/tmp"
    mountpoint /run 1>/dev/null 2>&1 && assert mount --rbind /run "$RUNTIME_ROOT/root/run"
    __UU_CHROOTED=1 assert exec chroot "$RUNTIME_ROOT/root" bash "$(realpath "$0")" "$@"
else
    umount /dev/resolve.conf 2> /dev/null
fi

# shellcheck disable=SC2064
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# prepare network
assert ip link set up dev lo

# sync all interfaces
function sync_interfaces() {
    echo "syncing interface"
    
    assert nsenter --target $PPID --net ip route show default table main | while read -r interface
    do
        dev=$(echo "$interface" | sed -n 's/.*dev \([^ ]*\).*/\1/p')
        
        mac_address_file="$PERSIST_ROOT/mac/$dev"
        [ -f "$mac_address_file" ] && mac_address=$(xargs < "$PERSIST_ROOT/mac/$dev")
        if [ -z "$mac_address" ];then
            mac_address=$(printf "00:%02x:%02x:%02x:%02x:%02x" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
            mkdir -p "$PERSIST_ROOT/mac"
            echo -n "$mac_address" > "$mac_address_file"
        fi
        
        echo "$dev: $mac_address"
        
        if nsenter --target $PPID --net ip link add "$dev.1" netns $$ link "$dev" type macvlan; then
            assert ip link set up name "$dev" address "$mac_address" dev "$dev.1"
        fi
    done
}

# auto call sync_all_interfaces on route changed
function auto_sync_interfaces() {
    assert nsenter --target $PPID --net ip monitor route | while read -r _
    do
        assert sync_interfaces
    done
}

# initial sync interfaces
assert sync_interfaces

# auto sync interfaces
auto_sync_interfaces &

# start dhcpcd
dhcpcd -B &

# wait default gateway ready
while ! ip route get 1.1.1.1 1>/dev/null 2>&1;
do
    echo "waiting network ready...1s"
    sleep 1
done

sleep 5
echo "network ready"

# install uu plugin
if [ ! -f "/home/deck/uu/uuplugin_monitor.sh" ]; then
    echo "installing uu plugin..."
    curl -s uudeck.com | sed 's/check_running$//g' | bash
    
    if [ ! -f "/home/deck/uu/uuplugin_monitor.sh" ]; then
        exit 1
    fi
fi

# start uu plugin
/home/deck/uu/uuplugin_monitor.sh
