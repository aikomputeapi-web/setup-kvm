#!/usr/bin/env bash

# Clear terminal for clean dashboard view
clear

# ==========================================
# 🌟 PREMIUM COLOR CODES & FX
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# FUNCTION: TYPING EFFECT ANIMATION
type_effect() {
    local text="$1"
    local delay="$2"
    for (( i=0; i<${#text}; i++ )); do
        echo -n "${text:$i:1}"
        sleep "$delay"
    done
    echo ""
}

# FUNCTION: LOADING BAR ANIMATION
loading_bar() {
    local title="$1"
    echo -ne "${YELLOW}⏳ $title ${NC}[          ]"
    sleep 0.3
    echo -ne "\b\b\b\b\b\b\b\b\b\b\b[===       ]"
    sleep 0.3
    echo -ne "\b\b\b\b\b\b\b\b\b\b\b[======     ]"
    sleep 0.3
    echo -ne "\b\b\b\b\b\b\b\b\b\b\b[=========  ]"
    sleep 0.3
    echo -ne "\b\b\b\b\b\b\b\b\b\b\b[==========]"
    echo -e " ${GREEN}DONE!${NC}"
}

# AUTOMATED ROOT/SUDO PRIVILEGE CHECK
if [ "$(id -u)" -eq 0 ]; then
    SUDO_CMD=""
else
    SUDO_CMD="sudo"
fi

# ==========================================
# MAIN INTERACTIVE LIST MENU
# ==========================================
show_menu() {
    clear
    echo -e "${RED}==========================================================${NC}"
    echo -e "${WHITE}          [👹 KVM VPS PREMIUM SERVER DASHBOARD 👹]          ${NC}"
    echo -e "${RED}==========================================================${NC}"
    echo -e "${WHITE}                ┌─────────────────────────┐               ${NC}"
    echo -e "${WHITE}                │  ${RED}█▀█ █▀▀█ █▀▄▀█ █▄▄█${WHITE}   │  <[KVM PRO] ${NC}"
    echo -e "${WHITE}                │  ${RED}█▄█ █▄▄█ █─▀─█ █▄▄█${WHITE}   │               ${NC}"
    echo -e "${WHITE}                └─────────────────────────┘               ${NC}"
    echo -e "${PURPLE}                   (█)─(█)     (█)─(█)                   ${NC}"
    echo -e "${PURPLE}                  █████████   █████████                  ${NC}"
    echo -e "${RED}                 ███████████████████████                 ${NC}"
    echo -e "${RED}==========================================================${NC}"
    echo -e "${CYAN}  _  __     _    _  ____  _____      ____  ___  ____  ${NC}"
    echo -e "${CYAN} | |/ /    / \  | |/ /  |/ ___|    |___ \|_ _|/ ___| ${NC}"
    echo -e "${CYAN} | ' /    / _ \ | ' /| | | |  _      __) || | \___ \ ${NC}"
    echo -e "${CYAN} | . \   / ___ \| . \| | | |_| |    / __/ | |  ___) |${NC}"
    echo -e "${CYAN} |_|\_\ /_/   \_\_|\_\_|  \____|   |_____|___||____/ ${NC}"
    echo -e "${RED}==========================================================${NC}"
    echo ""
    echo -e "${YELLOW}👉 SELECT AN OPTION TO PROCEED FROM LIST:${NC}"
    echo ""
    echo -e "  ${CYAN}[1]${NC} Install KVM Stack (One-Time Setup)"
    echo -e "  ${CYAN}[2]${NC} Create & Boot New Ubuntu VM Instance"
    echo -e "  ${CYAN}[3]${NC} List VMs & Get Connect Info"
    echo -e "  ${CYAN}[4]${NC} Restart Existing VM Instance"
    echo -e "  ${CYAN}[5]${NC} Remove/Delete VM Instance"
    echo -e "  ${CYAN}[6]${NC} Exit Dashboard"
    echo ""
    echo -e "${RED}==========================================================${NC}"
    echo -ne "${WHITE}🔹 Enter Choice [1-6]: ${NC}"
    read CHOICE

    case $CHOICE in
        1) install_kvm ;;
        2) create_vps ;;
        3) list_vps ;;
        4) restart_vps ;;
        5) remove_vps ;;
        6) exit 0 ;;
        *) echo -e "${RED}❌ Invalid Choice! Please select 1-6.${NC}"; sleep 2; show_menu ;;
    esac
}

# STEP 0: INSTALL THE FULL KVM/LIBVIRT STACK
install_kvm() {
    clear
    echo -e "${RED}==========================================================${NC}"
    echo -e "${WHITE}⚙️  INSTALLING KVM + LIBVIRT VIRTUALIZATION STACK${NC}"
    echo -e "${RED}==========================================================${NC}"
    echo ""

    loading_bar "Updating Package Lists"
    $SUDO_CMD apt-get update -y > /dev/null 2>&1

    loading_bar "Installing KVM/QEMU Core Engine"
    $SUDO_CMD DEBIAN_FRONTEND=noninteractive apt-get install -y \
        qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients \
        virtinst bridge-utils dnsmasq-base dnsmasq-utils ebtables iptables \
        cloud-image-utils genisoimage wget curl > /dev/null 2>&1

    loading_bar "Activating libvirtd Service"
    $SUDO_CMD systemctl enable libvirtd > /dev/null 2>&1
    $SUDO_CMD systemctl start libvirtd > /dev/null 2>&1

    if [ -n "${SUDO_USER:-}" ]; then
        loading_bar "Granting libvirt Access to $SUDO_USER"
        $SUDO_CMD usermod -aG libvirt "$SUDO_USER" > /dev/null 2>&1
        $SUDO_CMD usermod -aG kvm "$SUDO_USER" > /dev/null 2>&1
    fi

    loading_bar "Configuring Default NAT Network"
    $SUDO_CMD virsh net-start default > /dev/null 2>&1 || true
    $SUDO_CMD virsh net-autostart default > /dev/null 2>&1

    echo ""
    if [ -e /dev/kvm ]; then
        echo -e "${GREEN}✅ KVM ACCELERATION READY! (/dev/kvm detected)${NC}"
    else
        echo -e "${RED}⚠️ /dev/kvm missing — enable virtualization in BIOS/nested virt.${NC}"
    fi
    echo -e "${YELLOW}🔄 NOTE: Log out/in (or newgrp libvirt) to use virsh without sudo.${NC}"
    echo ""
    read -p "Press Enter to return to dashboard..." _
    show_menu
}

# STEP 1: CREATE VM — ASKS FOR VM SIZE
create_vps() {
    clear
    echo -e "${RED}==========================================================${NC}"
    echo -e "${WHITE}⚙️  CONFIGURE YOUR VIRTUAL MACHINE SPECIFICATIONS${NC}"
    echo -e "${RED}==========================================================${NC}"
    echo ""

    echo -ne "${BLUE}🔹 Enter VM Name (Default: ubuntu-vm): ${NC}"
    read VM_NAME
    VM_NAME=${VM_NAME:-ubuntu-vm}

    echo -ne "${BLUE}🔹 Enter RAM Size in GB (e.g., 2, 4, 8, 16, 32): ${NC}"
    read RAM_GB
    RAM_GB=${RAM_GB:-2}

    echo -ne "${BLUE}🔹 Enter CPU Cores (e.g., 1, 2, 4, 8): ${NC}"
    read CPU_CORES
    CPU_CORES=${CPU_CORES:-2}

    echo -ne "${BLUE}🔹 Enter DISK Size in GB (e.g., 10, 20, 50, 100): ${NC}"
    read DISK_GB
    DISK_GB=${DISK_GB:-20}

    echo -ne "${BLUE}🔹 Create Username (Default: ubuntu): ${NC}"
    read USER_NAME
    USER_NAME=${USER_NAME:-ubuntu}

    echo -ne "${BLUE}🔹 Create Password (Default: 1234): ${NC}"
    read USER_PASS
    USER_PASS=${USER_PASS:-1234}

    # sanity check CPU/RAM aren't nonsense
    RAM_GB=$(echo "$RAM_GB" | grep -oE '^[0-9]+$' || echo 2)
    CPU_CORES=$(echo "$CPU_CORES" | grep -oE '^[0-9]+$' || echo 2)
    DISK_GB=$(echo "$DISK_GB" | grep -oE '^[0-9]+$' || echo 20)

    echo ""
    echo -e "${YELLOW}⏳ Background core dependencies install ho rahi hain... Please wait.${NC}"
    echo ""

    $SUDO_CMD apt-get update -y > /dev/null 2>&1
    $SUDO_CMD apt-get install -y qemu-kvm qemu-utils libvirt-clients virtinst cloud-image-utils wget curl > /dev/null 2>&1

    # Custom absolute path architecture build
    $SUDO_CMD mkdir -p /var/lib/libvirt/images > /dev/null 2>&1
    BASE_IMAGE="/var/lib/libvirt/images/jammy-base.img"
    VM_IMAGE="/var/lib/libvirt/images/${VM_NAME}.qcow2"

    if [ ! -f "$BASE_IMAGE" ]; then
        echo -e "${YELLOW}📥 Downloading Ubuntu 22.04 Cloud Image to /var/lib/libvirt/images/...${NC}"
        $SUDO_CMD wget -q --show-progress https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O "$BASE_IMAGE"
        $SUDO_CMD chmod 666 "$BASE_IMAGE"
    else
        echo -e "${GREEN}✅ Existing Image Cache Detected at $BASE_IMAGE.${NC}"
    fi

    loading_bar "Generating Cloud-Init Matrix"
    cat <<EOF > user-data
#cloud-config
ssh_pwauth: True
chpasswd:
  list: |
    ${USER_NAME}:${USER_PASS}
  expire: False
EOF

    loading_bar "Allocating Server Hard Disk (${DISK_GB}G)"
    $SUDO_CMD qemu-img create -f qcow2 -b "$BASE_IMAGE" -F qcow2 "$VM_IMAGE" ${DISK_GB}G > /dev/null 2>&1

    save_env
    boot_qemu
}

save_env() {
    cat > .vps_env <<EOF
VM_NAME=${VM_NAME:-ubuntu-vm}
VM_IMAGE=${VM_IMAGE:-/var/lib/libvirt/images/ubuntu-vm.qcow2}
RAM_GB=${RAM_GB:-2}
CPU_CORES=${CPU_CORES:-2}
DISK_GB=${DISK_GB:-20}
USER_NAME=${USER_NAME:-ubuntu}
USER_PASS=${USER_PASS:-1234}
EOF
}

# STEP 2: BOOT THE VM WITH THE SELECTED SPECS
boot_qemu() {
    if [ -f ".vps_env" ]; then
        source .vps_env
    fi

    RAM_VALUE="${RAM_GB:-2}G"

    clear
    echo -e "${GREEN}==========================================================${NC}"
    type_effect "👹 DATA SYSTEM SYNCHRONIZED! PIPING TERMINAL CHANNELS..." 0.02
    echo -e "${GREEN}==========================================================${NC}"
    echo ""

    loading_bar "Booting KVM Accelerated VM Instance"

    # Fresh seed image for this boot
    $SUDO_CMD cloud-localds seed.img user-data > /dev/null 2>&1

    # Boot the VM headless under libvirt
    $SUDO_CMD virt-install \
        --name "$VM_NAME" \
        --memory "$RAM_VALUE" \
        --vcpus "$CPU_CORES" \
        --disk path="$VM_IMAGE",format=qcow2 \
        --disk path="$PWD/seed.img",device=cdrom,format=raw \
        --os-variant ubuntu22.04 \
        --network network=default \
        --import \
        --graphics none --noautoconsole --noreboot > /dev/null 2>&1

    $SUDO_CMD virsh start "$VM_NAME" > /dev/null 2>&1

    clear
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "🎉  KVM VPS - VIRTUAL MACHINE NETWORK ACTIVE        "
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${WHITE}🖥️  VM Name   : ${CYAN}${VM_NAME:-ubuntu-vm}${NC}"
    echo -e "${WHITE}👤 Username  : ${CYAN}${USER_NAME:-ubuntu}${NC}"
    echo -e "${WHITE}🔑 Password  : ${CYAN}${USER_PASS:-1234}${NC}"
    echo -e "${WHITE}⚙️  Resources : ${CYAN}${RAM_VALUE} RAM | ${CPU_CORES:-2} Cores | ${DISK_GB:-20}G Disk${NC}"
    echo -e "${RED}----------------------------------------------------------${NC}"
    echo -e "${WHITE}👉 SSH Connect : ssh ${USER_NAME:-ubuntu}@localhost -p 22${NC}"
    echo -e "${WHITE}👉 (or find IP with: virsh domifaddr ${VM_NAME:-ubuntu-vm})${NC}"
    echo -e "${RED}----------------------------------------------------------${NC}"
    echo -e "${YELLOW}🔄 To restart later, use Option 4. To remove, use Option 5.${NC}"
    echo -e "${GREEN}==========================================================${NC}"
    echo ""
    read -p "Press Enter to return to dashboard..." _
    show_menu
}

# STEP 3: LIST VMs
list_vps() {
    clear
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${WHITE}📋 CURRENT VIRTUAL MACHINE INVENTORY${NC}"
    echo -e "${GREEN}==========================================================${NC}"
    echo ""
    $SUDO_CMD virsh list --all
    echo ""
    echo -ne "${BLUE}🔹 Enter VM name for connect info (blank to skip): ${NC}"
    read VM_NAME
    if [ -n "$VM_NAME" ]; then
        echo ""
        echo -e "${YELLOW}IP Address:${NC}"
        $SUDO_CMD virsh domifaddr "$VM_NAME" || echo -e "${RED}Could not fetch IP. VM may be off.${NC}"
        echo ""
        echo -e "${YELLOW}SSH Command:${NC}"
        IP=$($SUDO_CMD virsh domifaddr "$VM_NAME" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)
        if [ -n "$IP" ]; then
            echo -e "${GREEN}ssh ubuntu@${IP}${NC}"
        fi
    fi
    echo ""
    read -p "Press Enter to return to dashboard..." _
    show_menu
}

# STEP 4: RESTART VM
restart_vps() {
    echo ""
    echo -ne "${BLUE}🔹 Enter VM name to restart: ${NC}"
    read VM_NAME
    if [ -n "$VM_NAME" ]; then
        $SUDO_CMD virsh reboot "$VM_NAME" 2>/dev/null || $SUDO_CMD virsh start "$VM_NAME" 2>/dev/null || \
            echo -e "${RED}❌ VM not found. Build one using Option 2.${NC}"
    fi
    echo ""
    read -p "Press Enter to return to dashboard..." _
    show_menu
}

# STEP 5: REMOVE VM
remove_vps() {
    echo ""
    echo -ne "${BLUE}🔹 Enter VM name to remove: ${NC}"
    read VM_NAME
    if [ -n "$VM_NAME" ]; then
        $SUDO_CMD virsh destroy "$VM_NAME" > /dev/null 2>&1
        $SUDO_CMD virsh undefine "$VM_NAME" > /dev/null 2>&1
        $SUDO_CMD rm -f "/var/lib/libvirt/images/${VM_NAME}.qcow2"
        echo -e "${GREEN}✅ VM '$VM_NAME' removed successfully!${NC}"
    fi
    echo ""
    read -p "Press Enter to return to dashboard..." _
    show_menu
}

# EXECUTE TRIGGER
show_menu
