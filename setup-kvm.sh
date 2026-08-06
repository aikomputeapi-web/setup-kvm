#!/usr/bin/env bash
#
# setup-kvm.sh - Install a complete KVM/libvirt stack on Debian/Ubuntu
#
# Usage:
#   sudo ./setup-kvm.sh                 # basic install + default NAT network
#   sudo ./setup-kvm.sh --bridge ens3   # also create a bridged network on ens3
#
# Run over SSH:
#   ssh user@server 'sudo bash -s' < setup-kvm.sh
#   # or
#   scp setup-kvm.sh user@server:/tmp && ssh user@server 'sudo bash /tmp/setup-kvm.sh'
#
# This script must be run as root.

set -euo pipefail

# ---------------------------------------------------------------- helpers --
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { printf "${GREEN}==>${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}!!>${NC} %s\n" "$*"; }
die()   { printf "${RED}ERROR:${NC} %s\n" "$*" >&2; exit 1; }

BRIDGE_IFACE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bridge)
      [[ $# -gt 1 ]] || die "--bridge requires an interface name (e.g. --bridge ens3)"
      BRIDGE_IFACE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,10p' "$0"; exit 0 ;;
    *)
      die "Unknown argument: $1 (try --help)" ;;
  esac
done

# ------------------------------------------------------------------ checks --
[[ $(id -u) -eq 0 ]] || die "Must be run as root (use sudo)."
[[ -n "${SUDO_USER:-}" ]] || warn "No sudo user detected; skipping group memberships."

# Detect distro + release
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
else
  die "Cannot detect OS (/etc/os-release missing)."
fi

case "$ID" in
  debian|ubuntu) ;;
  *) die "Unsupported distro '$ID'. This script targets Debian/Ubuntu." ;;
esac

info "Detected: $PRETTY_NAME ($VERSION_CODENAME)"

# CPU virtualization support check
if [[ ! -e /dev/kvm ]]; then
  if ! grep -qE '(vmx|svm)' /proc/cpuinfo; then
    warn "CPU lacks VMX/SVM flags and /dev/kvm is missing."
    warn "KVM won't work on bare metal without these. If this host is itself a VM, enable nested virtualization."
    warn "Continuing with install anyway so packages are ready."
  else
    warn "/dev/kvm not present (kernel module kvm_intel/kvm_amd not loaded?). Continuing anyway."
  fi
else
  info "KVM acceleration available (/dev/kvm present)."
fi

# ------------------------------------------------------------ apt packages --
export DEBIAN_FRONTEND=noninteractive

info "Updating package lists..."
apt-get update -y

# Base KVM stack. Names differ slightly between distros/releases; install all
# that exist and ignore the few that don't.
BASE_PKGS="qemu-kvm libvirt-daemon-system libvirt-clients virtinst \
bridge-utils dnsmasq-base dnsmasq-utils ebtables iptables \
cloud-image-utils genisoimage python3-pip"

# Debian ships virtinst; some Ubuntu versions name it python3-virtinst as well.
# libvirt-bin was the old (pre-18.04) Ubuntu package name.
case "$ID" in
  ubuntu)
    if [[ "${VERSION_ID%%.*}" -ge 20 ]]; then
      EXTRA_PKGS="python3-virtinst"
    else
      BASE_PKGS="${BASE_PKGS/libvirt-daemon-system/libvirt-bin}"
      EXTRA_PKGS=""
    fi
    ;;
  debian)
    EXTRA_PKGS=""
    ;;
esac

info "Installing KVM/libvirt packages..."
# shellcheck disable=SC2086
apt-get install -y $BASE_PKGS $EXTRA_PKGS

# Legacy network filter packages on Debian 11 / older libvirt
apt-get install -y libnss-libvirt 2>/dev/null || true

# ------------------------------------------------------------ libvirtd -----
info "Enabling and starting libvirtd..."
systemctl enable libvirtd
systemctl start libvirtd || { warn "libvirtd failed to start. See: journalctl -u libvirtd -n 50"; }

systemctl enable virtlogd 2>/dev/null || true
systemctl start virtlogd 2>/dev/null || true

# --------------------------------------------- user group membership --------
if [[ -n "${SUDO_USER:-}" ]]; then
  info "Adding user '$SUDO_USER' to libvirt and kvm groups..."
  usermod -aG libvirt "$SUDO_USER"
  usermod -aG kvm "$SUDO_USER"
  warn "User '$SUDO_USER' must log out/in (or run 'newgrp libvirt') for group changes to apply."
fi

# -------------------------------------------------- default NAT network -----
info "Configuring default libvirt NAT network (192.168.122.0/24)..."
if ! virsh net-list --all | grep -q '^ default '; then
  virsh net-define /usr/share/libvirt/networks/default.xml || true
fi
virsh net-start default 2>/dev/null || warn "default network already running (or failed to start)."
virsh net-autostart default

# ------------------------------------------------------ bridge (optional) ---
if [[ -n "$BRIDGE_IFACE" ]]; then
  info "Setting up bridged networking on interface $BRIDGE_IFACE..."
  if ! ip link show "$BRIDGE_IFACE" >/dev/null 2>&1; then
    die "Interface '$BRIDGE_IFACE' not found. Aborting bridge creation."
  fi

  BRIDGE_NAME=br0

  case "$ID" in
    ubuntu)
      # Find which netplan file manages this interface (if any).
      NP_FILE=""
      for f in /etc/netplan/*.yaml /etc/netplan/*.yml; do
        [[ -e "$f" ]] || continue
        if grep -q "$BRIDGE_IFACE" "$f"; then
          NP_FILE="$f"; break
        fi
      done
      if [[ -n "$NP_FILE" ]]; then
        info "Configuring bridge via netplan ($NP_FILE)..."
        cp "$NP_FILE" "$NP_FILE.bak.$(date +%s)"
        cat > /tmp/netplan-bridge.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $BRIDGE_IFACE:
      dhcp4: false
  bridges:
    $BRIDGE_NAME:
      interfaces: [$BRIDGE_IFACE]
      dhcp4: true
EOF
        install -m 600 /tmp/netplan-bridge.yaml "$NP_FILE"
        info "Applying netplan... (connectivity may briefly drop)"
        netplan apply || warn "netplan apply failed; restore backup and check $NP_FILE"
      else
        warn "No netplan file manages '$BRIDGE_IFACE' — skipping automatic bridge config."
        warn "Create the bridge manually: see https://libvirt.org/networking-bridge.html"
      fi
      ;;
    debian)
      # Legacy ifupdown based config (Debian 12 default is netplan if installed).
      if [[ -f /etc/network/interfaces ]] && grep -q "iface $BRIDGE_IFACE" /etc/network/interfaces; then
        cp /etc/network/interfaces /etc/network/interfaces.bak.$(date +%s)
        cat >> /etc/network/interfaces <<EOF

auto $BRIDGE_NAME
iface $BRIDGE_NAME inet dhcp
    bridge_ports $BRIDGE_IFACE
    bridge_stp off
    bridge_fd 0
EOF
        info "Bridge added to /etc/network/interfaces (applies on next boot or 'systemctl restart networking')."
      else
        warn "No ifupdown config found for '$BRIDGE_IFACE' — skipping automatic bridge config."
        warn "Create the bridge manually: see https://libvirt.org/networking-bridge.html"
      fi
      ;;
  esac
fi

# ------------------------------------------------------------- validation ---
echo
info "Verification:"
virsh net-list --all || true
echo
if [[ -e /dev/kvm ]]; then
  info "KVM OK: /dev/kvm present."
else
  warn "KVM NOT available: /dev/kvm missing."
fi
echo "  You can run a VM by placing an ISO in /var/lib/libvirt/images and using:"
echo "    sudo virt-install --name testvm --memory 2048 --vcpus 2 \\"
echo "      --disk size=20 --cdrom /var/lib/libvirt/images/ubuntu.iso \\"
echo "      --os-variant ubuntu24.04 --network default --graphics spice"
echo
info "Done. A fresh SSH session may be required for libvirt group access."
