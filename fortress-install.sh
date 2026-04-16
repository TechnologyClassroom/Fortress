#!/bin/bash

# fortress-install.sh
# Copyright (C) 2026 Michael McMahon <michael@gnu.org>
# Installer for Fortress. https://github.com/hackman/Fortress

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

set -euo pipefail
#set -euxo pipefail  # DEBUG

echo "This script installs and configures Fortress for iptables or ipset."
echo "https://github.com/hackman/Fortress"

# Initialization checks.

# Check for /bin/bash.
if [ "$BASH_VERSION" = '' ]; then
  echo "You are not using bash."
  echo "Use this syntax instead:"
  echo "  sudo bash fortress-install.sh"
  exit 1
fi

# Check for root.
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

# Create config directory.
echo "Creating fortress directories..."
mkdir -p /etc/fortress
mkdir -p /usr/share/fortress
mkdir -p /usr/lib/fortress
mkdir -p /var/log/fortress
mkdir -p /var/run/fortress
mkdir -p /var/cache/fortress
mkdir -p /etc/systemd/system

# Copy configuration files.
echo "Copying configuration files..."
config="/etc/fortress/fortress.conf"
cp fortress.conf "$config"
# Copy exclude files.
cp excludes/baidu.txt /etc/fortress/
cp excludes/bingbot.txt /etc/fortress/
cp excludes/cloudflare.txt /etc/fortress/
cp excludes/google.txt /etc/fortress/
cp excludes/msnbot.txt /etc/fortress/
cp excludes/my.txt /etc/fortress/
cp excludes/yahoo.txt /etc/fortress/
cp excludes/yandex.txt /etc/fortress/
# Copy LICENSE file.
cp LICENSE /usr/share/fortress

# Check dependencies.
# Mandatory: Perl's Net::Patricia module
#   For package names across operating systems reference:
#   https://repology.org/project/perl%3Anet-patricia/versions
# Optional: ipset
#   For package names across operating systems reference:
#   https://repology.org/project/ipset/versions

# Enable ipset configuration if present.
echo "Checking if ipset is installed..."
ipsetpresent=0
package="ipset"
# Check if dpkg is present.
if command -v dpkg >/dev/null 2>&1; then
  # Check if ipset is present.
  if dpkg -s $package >/dev/null 2>&1; then
    ipsetpresent=1
    echo "$package is installed."
  fi
  echo "Checking if libnet-patricia-perl is installed..."
  if dpkg -s libnet-patricia-perl >/dev/null 2>&1; then
    echo "libnet-patricia-perl is installed."
  else
    echo "Attempting to install the libnet-patricia-perl dependency..."
    apt-get install -y libnet-patricia-perl
  fi
fi
# Check if rpm is present.
if command -v rpm >/dev/null 2>&1; then
  # Check if ipset is present.
  if rpm -q $package >/dev/null 2>&1; then
    echo "$package is installed."
  fi
  echo "Checking if perl-Net-Patricia is installed..."
  if rpm -q perl-Net-Patricia >/dev/null 2>&1; then
    echo "perl-Net-Patricia is installed."
  else
    echo "Attempting to install the perl-Net-Patricia dependency..."
    if command -v yum >/dev/null 2>&1; then
      yum install -y perl-Net-Patricia
    fi
    if command -v dnf >/dev/null 2>&1; then
      dnf install -y perl-Net-Patricia
    fi
    if command -v zypper >/dev/null 2>&1; then
      zypper install -y perl-Net-Patricia
    fi
  fi
fi
if [ $ipsetpresent = 1 ]; then
  echo "Enabling ipset configuration..."
  sed -i 's/block_type=iptables/block_type=ipset/g' "$config"
  sed -i 's/#ipset_name=blocklist/ipset_name=fortress/g' "$config"
  echo "Note: Some additional steps are required to create the ipset and add"
  echo "the ipset to iptables."
else
  echo "ipset was not found with rpm or dpkg. The iptables configuration is"
  echo "the default and is currently applied. If you want Fortress to block"
  echo "with ipset, install the ipset package and run this script again."
fi
echo "If you want the redirection configuration, manual steps will need to be"
echo "taken to configure the redirection and setup the secondary server."

# Install Fortress scripts.
echo "Installing Fortress scripts..."
cp fortress.pl /usr/sbin/fortress
# These chmod entries should not be necessary, but they could be useful if
# someone places these files in a NTFS partition first.
chmod +x /usr/sbin/fortress
cp fortress-unblock.sh /usr/sbin/fortress-unblock
chmod +x /usr/sbin/fortress-unblock
cp fortress-block.sh /usr/sbin/fortress-block
chmod +x /usr/sbin/fortress-block

# SystemD
echo "Configuring systemd..."
# Install the service file.
cp fortress.service /etc/systemd/system/
# Reload systemctl.
systemctl daemon-reload
# Starting fortress service
systemctl start fortress

# Check if Fortress works.
echo "Checking if fortress started successfully..."

if ! systemctl is-active --quiet fortress ; then
  echo "Fortress failed to start. Troubleshooting is required. The following"
  echo "text is the output of this command:"
  echo '  journalctl -u fortress.service --since="today" --no-pager'
  journalctl -u fortress.service --since="today" --no-pager
  echo "Stopping Fortress service."
  systemctl stop fortress
  echo "Disabling Fortress service."
  systemctl disable fortress
  echo "Fortress failed to start."
  exit 1
else
  # Enable fortress service
  systemctl enable fortress
  echo "If all commands were successful and all dependencies were met, fortress"
  echo "should be running now and should start automatically after you reboot."
fi

exit 0
