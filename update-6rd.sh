#!/bin/bash

# USER VARIABLES
IPV6_6RD_PREFIX="2602::/24"
IPV6_6RD_BORDER_ROUTER="205.171.2.64/0"
MTU=1472
TTL=255
LAN_PREFIX_LENGTH=64
IPV6_DNS1=2606:4700:4700::1111
IPV6_DNS2=2606:4700:4700::1001

# Check for existence of ipv6calc
if ! [ -x "$(command -v ipv6calc)" ]; then
  # Attempt to install ipv6calc
  cd /tmp
  curl -sLO http://ftp.us.debian.org/debian/pool/main/i/ipv6calc/ipv6calc_0.93.1-2_mipsel.deb && dpkg -i ipv6calc_0.93.1-2_mipsel.deb
  rm ipv6calc_0.93.1-2_mipsel.deb
  cd -
  # Verify install
  if ! [ -x "$(command -v ipv6calc)" ]; then
    echo "Failed to install ipv6calc"
    exit 1
  fi
fi

PUBLIC_IP=`ip addr show dev pppoe0 | grep -oE 'inet [^ ]+' | cut -d' ' -f2`
IPV6_6RD_PREFIX_LENGTH=`echo ${IPV6_6RD_PREFIX} | cut -d'/' -f2`
IPV6_SUBNET=`ipv6calc --action 6rd_local_prefix --6rd_prefix ${IPV6_6RD_PREFIX} --6rd_relay_prefix ${IPV6_6RD_BORDER_ROUTER} ${PUBLIC_IP} 2>/dev/null | cut -d'/' -f1`
IPV6_ADDR="${IPV6_SUBNET}1"
IPV6_6RD_BORDER_ROUTER=`echo ${IPV6_6RD_BORDER_ROUTER} | cut -d'/' -f1`

echo "
configure

# Configure Tunnel
set interfaces tunnel tun0 6rd-prefix ${IPV6_6RD_PREFIX}
set interfaces tunnel tun0 address ${IPV6_ADDR}/${IPV6_6RD_PREFIX_LENGTH}
set interfaces tunnel tun0 description '6rd Tunnel'
set interfaces tunnel tun0 encapsulation sit
set interfaces tunnel tun0 local-ip ${PUBLIC_IP}
set interfaces tunnel tun0 mtu ${MTU}
set interfaces tunnel tun0 ttl ${TTL}
set interfaces tunnel tun0 6rd-default-gw ::${IPV6_6RD_BORDER_ROUTER}

# Configure LAN
set interfaces switch switch0 address ${IPV6_ADDR}/${LAN_PREFIX_LENGTH}
set interfaces switch switch0 ipv6 dup-addr-detect-transmits 1
set interfaces switch switch0 ipv6 router-advert dup-addr-detect-transmits 1
set interfaces switch switch0 ipv6 router-advert link-mtu ${MTU}
set interfaces switch switch0 ipv6 router-advert managed-flag false
set interfaces switch switch0 ipv6 router-advert max-interval 300
set interfaces switch switch0 ipv6 router-advert other-config-flag false
set interfaces switch switch0 ipv6 router-advert radvd-options \"RDNSS ${IPV6_DNS1} ${IPV6_DNS2} {};\"
set interfaces switch switch0 ipv6 router-advert reachable-time 0
set interfaces switch switch0 ipv6 router-advert retrans-timer 0
set interfaces switch switch0 ipv6 router-advert send-advert true
set interfaces switch switch0 ipv6 router-advert prefix ${IPV6_SUBNET}/${LAN_PREFIX_LENGTH} autonomous-flag true
set interfaces switch switch0 ipv6 router-advert prefix ${IPV6_SUBNET}/${LAN_PREFIX_LENGTH} on-link-flag true
set interfaces switch switch0 ipv6 router-advert prefix ${IPV6_SUBNET}/${LAN_PREFIX_LENGTH} valid-lifetime 86400

# Configure Firewall
set firewall ipv6-name WAN6_IN default-action drop
set firewall ipv6-name WAN6_IN description "WAN6 to internal"
set firewall ipv6-name WAN6_IN rule 10 action accept
set firewall ipv6-name WAN6_IN rule 10 description "Allow established/related"
set firewall ipv6-name WAN6_IN rule 10 state established enable
set firewall ipv6-name WAN6_IN rule 10 state related enable
set firewall ipv6-name WAN6_IN rule 20 action drop
set firewall ipv6-name WAN6_IN rule 20 description "Drop invalid state"
set firewall ipv6-name WAN6_IN rule 20 state invalid enable
set firewall ipv6-name WAN6_IN rule 30 action accept
set firewall ipv6-name WAN6_IN rule 30 description "allow ICMPv6"
set firewall ipv6-name WAN6_IN rule 30 protocol icmpv6

set firewall ipv6-name WAN6_LOCAL default-action drop
set firewall ipv6-name WAN6_LOCAL description "WAN6 to router"
set firewall ipv6-name WAN6_LOCAL rule 10 action accept
set firewall ipv6-name WAN6_LOCAL rule 10 description "Allow established/related"
set firewall ipv6-name WAN6_LOCAL rule 10 state established enable
set firewall ipv6-name WAN6_LOCAL rule 10 state related enable
set firewall ipv6-name WAN6_LOCAL rule 20 action drop
set firewall ipv6-name WAN6_LOCAL rule 20 description "Drop invalid state"
set firewall ipv6-name WAN6_LOCAL rule 20 state invalid enable
set firewall ipv6-name WAN6_LOCAL rule 30 action accept
set firewall ipv6-name WAN6_LOCAL rule 30 description "allow ICMPv6"
set firewall ipv6-name WAN6_LOCAL rule 30 protocol icmpv6

set interfaces tunnel tun0 firewall in ipv6-name WAN6_IN
set interfaces tunnel tun0 firewall local ipv6-name WAN6_LOCAL

commit
"
