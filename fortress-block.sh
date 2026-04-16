#!/bin/bash

# fortress-block.sh
# Copyright (C) 2023 Marian Marinov <mm@yuhu.biz>
# IP blocker for Fortress. https://github.com/hackman/Fortress

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, see
# <https://www.gnu.org/licenses/>.

config=/etc/fortress/fortress.conf

if [[ ! -f $config ]]; then
  echo "Missing configuration file: $config"
  exit
fi
redirect_ip=$(awk -F= '/redirect_ip/ && $1 !~ /^\s*#/ {print $2}' $config)
block_type=$( awk -F= '/block_type/  && $1 !~ /^\s*#/ {print $2}' $config)
block_time=$( awk -F= '/block_time/  && $1 !~ /^\s*#/ {print $2}' $config)

ip=''
comment=''

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 IP [comment]"
  exit
fi

if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: invalid IP format"
  exit
fi

# Parameters:
# 1 - IP
# 2 - Comment
ipset_block() {
  ip=$1
  shift
  ipset_name=$( awk -F= '/ipset_name/  && $1 !~ /^\s*#/ {print $2}' $config)
  if [[ -z $ipset_name ]]; then
    echo "Error: unable to find ipset_name in $config."
    echo -e "Please check the configuration and try again.\n"
    exit
  fi
  if [[ -n $1 ]]; then
    ipset add $ipset_name $ip comment "$*" timeout $block_time
  else
    ipset add $ipset_name $ip
  fi
}

# Parameters:
# 1 - IP
# 2 - Comment
iptables_block() {
  ip=$1
  shift
  chain=INPUT
  chain_name=$( awk -F= '/chain_name/  && $1 !~ /^\s*#/ {print $2}' $config)
  if [[ -n $chain_name ]]; then
    chain=$chain_name
  fi
  if [[ -n $1 ]]; then
    iptables -I $chain -j DROP -s $ip -m comment --comment "$*"
  else
    iptables -I $chain -j DROP -s $ip
  fi
}

# Parameters:
# 1 - IP
redirection() {
  if [[ -z $redirect_ip ]]; then
    echo "No redirect IP defined. Quiting without redirection."
    exit 1
  fi
  iptables -t nat -A PREROUTING -j DNAT -s $1 -p tcp --dport 80  --to $redirect_ip
  iptables -t nat -A PREROUTING -j DNAT -s $1 -p tcp --dport 443 --to $redirect_ip
  iptables -t nat -A PREROUTING -j DNAT -s $1 -p udp --dport 443 --to $redirect_ip
}

case "$block_type" in
  ipset)
    ipset_block $*
  ;;
  iptables)
    iptables_block $*
  ;;
  redirect)
    redirection $*
  ;;
  *)
    echo "Error: unsupported block type in the configuration $config"
  ;;
esac
