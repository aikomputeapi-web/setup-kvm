#!/usr/bin/env bash

# Clear terminal for clean dashboard view
clear

# If stdin is not a terminal (e.g. piped via curl | bash), reattach it so
# interactive 'read' works. Otherwise the menu never receives key presses.
if [ ! -t 0 ]; then
    exec </dev/tty
fi

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

# ==========================================
# 🗂️  GLOBAL PATHS & DEFAULTS
# ==========================================
VPS_DIR="$HOME/kvm-vps"
BASE_DIR="$VPS_DIR/base"
TCP_HOST_PORT=2222
TCP_GUEST_PORT=22
RAM_GB=2
CPU_CORES=2
DISK_GB=10
USER_NAME=ubuntu
USER_PASS=1221
VM_NAME=ubuntu-vm
SSH_KEY=""
CF_HOST=""

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
# HELPER: VM RUNNING CHECK
# ==========================================
vm_running() {
    [ -f "$VPS_DIR/$VM_NAME/vm.pid" ] && kill -0 "$(cat "$VPS_DIR/$VM_NAME/vm.pid")" 2>/dev/null
}

# ==========================================
# HELPER: NUMBERED VM SELECTOR
# Lists all VMs as a numbered menu and sets VM_NAME.
# Returns 0 on selection, 1 if there are no VMs (or user cancels with 0).
# ==========================================
select_vm() {
    local prompt="$1"
    local idx=0
    VM_NAMES=()
    for env in "$VPS_DIR"/*/.vps_env; do
        [ -f "$env" ] || continue
        idx=$((idx + 1))
        VM_NAMES+=("$(basename "$(dirname "$env")")")
    done

    if [ "$idx" -eq 0 ]; then
        echo -e "${RED}❌ No VMs found. Build one using Option 2.${NC}"
        return 1
    fi

    echo ""
    echo -e "${WHITE}$prompt${NC}"
    echo ""
    local n=1
    for name in "${VM_NAMES[@]}"; do
        echo -e "  ${CYAN}[${n}]${NC} ${name}"
        n=$((n + 1))
    done
    echo -e "  ${CYAN}[0]${NC} Cancel"
    echo ""
    echo -ne "${BLUE}🔹 Enter Choice [0-${idx}]: ${NC}"
    read SEL_NUM

    if [ -z "$SEL_NUM" ] || ! echo "$SEL_NUM" | grep -qE '^[0-9]+$' || [ "$SEL_NUM" -lt 1 ] || [ "$SEL_NUM" -gt "$idx" ]; then
        echo -e "${RED}❌ Invalid choice.${NC}"
        return 1
    fi

    VM_NAME="${VM_NAMES[$((SEL_NUM - 1))]}"
    return 0
}

# ==========================================
# MAIN INTERACTIVE LIST MENU
# ==========================================
show_menu() {
    clear
    echo -e "${RED}==========================================================${NC}"
    echo -e "${WHITE}          [👹 KVM VPS PREMIUM SERVER DASHBOARD 👹]          ${NC}"
    echo -e "${RED}==========================================================${NC}"
    echo -e "${WHITE}                ┌─────────────────────────┐               ${NC}"
    echo -e "${WHITE}                │  ${RED}█▀█ █▀▀█ █▀▄▀█ █▄▄█${WHITE}   │  <[QEMU PRO] ${NC}"
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
    echo -e "  ${CYAN}[1]${NC} Install Dependencies (qemu + cloudflared + tools)"
    echo -e "  ${CYAN}[2]${NC} Create & Boot New Ubuntu VM"
    echo -e "  ${CYAN}[3]${NC} VM Status & Connect Info"
    echo -e "  ${CYAN}[4]${NC} Restart VM Instance"
    echo -e "  ${CYAN}[5]${NC} Stop VM Instance"
    echo -e "  ${CYAN}[6]${NC} Remove/Delete VM Instance"
    echo -e "  ${CYAN}[7]${NC} Enable/Disable Autostart on Boot"
    echo -e "  ${CYAN}[8]${NC} Exit Dashboard"
    echo ""
    echo -e "${RED}==========================================================${NC}"
    echo -ne "${WHITE}🔹 Enter Choice [1-8]: ${NC}"
    read CHOICE

    case $CHOICE in
        1) install_deps ;;
        2) create_vps ;;
        3) vps_status ;;
        4) restart_vps ;;
        5) stop_vps ;;
        6) remove_vps ;;
        7) toggle_autostart ;;
        8) exit 0 ;;
        *) echo -e "${RED}❌ Invalid Choice! Please select 1-8.${NC}"; sleep 2; show_menu ;;
    esac
}

# ==========================================
# STEP 0: INSTALL DEPENDENCIES
# ==========================================
install_deps() {
    clear
    echo -e "${RED}==========================================================${NC}"
    echo -e "${WHITE}⚙️  INSTALLING QEMU + CLOUDFLARE DEPENDENCIES${NC}"
    echo -e "${RED}==========================================================${NC}"
    echo ""

    loading_bar "Updating Package Lists"
    $SUDO_CMD apt-get update -y > /dev/null 2>&1

    loading_bar "Installing QEMU + Cloud Tools"
    $SUDO_CMD apt-get install -y \
        qemu-system-x86 qemu-utils cloud-image-utils wget curl iproute2 > /dev/null 2>&1

    loading_bar "Installing cloudflared (Cloudflare Tunnel)"
    if ! command -v cloudflared > /dev/null 2>&1; then
        $SUDO_CMD wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
            -O /usr/local/bin/cloudflared
        $SUDO_CMD chmod +x /usr/local/bin/cloudflared
    else
        echo -e "${GREEN}✅ cloudflared already installed: $(cloudflared --version)${NC}"
    fi

    echo ""
    KVM_OK=0
    if [ -e /dev/kvm ] && exec 3<>/dev/kvm 2>/dev/null; then
        exec 3>&- 3<&-
        KVM_OK=1
    fi
    if [ "$KVM_OK" = "1" ]; then
        echo -e "${GREEN}✅ KVM ACCELERATION AVAILABLE — VMs will run FAST.${NC}"
    else
        echo -e "${YELLOW}⚠️  /dev/kvm not usable — using SOFTWARE emulation (TCG).${NC}"
        echo -e "${YELLOW}   VMs run slower but still work in the sandbox.${NC}"
    fi
    echo ""
    read -p "Press Enter to return to dashboard..." _
    show_menu
}

install_deps_silent() {
    if ! command -v qemu-system-x86_64 > /dev/null 2>&1; then
        $SUDO_CMD apt-get update -y > /dev/null 2>&1
        $SUDO_CMD apt-get install -y \
            qemu-system-x86 qemu-utils cloud-image-utils wget curl iproute2 > /dev/null 2>&1
    fi
    if ! command -v cloudflared > /dev/null 2>&1; then
        $SUDO_CMD wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
            -O /usr/local/bin/cloudflared
        $SUDO_CMD chmod +x /usr/local/bin/cloudflared
    fi
}

# ==========================================
# STEP 1: CREATE & BOOT VM
# ==========================================
create_vps() {
    clear
    echo -e "${RED}==========================================================${NC}"
    echo -e "${WHITE}⚙️  CONFIGURE YOUR VIRTUAL MACHINE SPECIFICATIONS${NC}"
    echo -e "${RED}==========================================================${NC}"
    echo ""

    echo -ne "${BLUE}🔹 Enter VM Name (Default: ubuntu-vm): ${NC}"
    read VM_NAME
    VM_NAME=${VM_NAME:-ubuntu-vm}

    if vm_running; then
        echo -e "${RED}❌ VM '$VM_NAME' is already running!${NC}"; sleep 2; show_menu
    fi

    echo -ne "${BLUE}🔹 Enter RAM Size in GB (e.g., 2, 4, 8): ${NC}"
    read RAM_GB
    echo -ne "${BLUE}🔹 Enter CPU Cores (e.g., 1, 2, 4): ${NC}"
    read CPU_CORES
    echo -ne "${BLUE}🔹 Enter DISK Size in GB (e.g., 10, 20, 50): ${NC}"
    read DISK_GB
    echo -ne "${BLUE}🔹 Enter SSH Host Port (Default: 2222): ${NC}"
    read TCP_HOST_PORT

    echo -ne "${BLUE}🔹 Create Username (Default: ubuntu): ${NC}"
    read USER_NAME
    USER_NAME=${USER_NAME:-ubuntu}

    echo -ne "${BLUE}🔹 Password (Default: 1221): ${NC}"
    read USER_PASS
    USER_PASS=${USER_PASS:-1221}

    echo -ne "${BLUE}🔹 SSH public key to install (blank to skip): ${NC}"
    read SSH_KEY

    # Sanity-check numeric inputs
    RAM_GB=$(echo "$RAM_GB" | grep -oE '^[0-9]+$' || echo 2)
    CPU_CORES=$(echo "$CPU_CORES" | grep -oE '^[0-9]+$' || echo 2)
    DISK_GB=$(echo "$DISK_GB" | grep -oE '^[0-9]+$' || echo 10)
    TCP_HOST_PORT=$(echo "$TCP_HOST_PORT" | grep -oE '^[0-9]+$' || echo 2222)
    [ "$TCP_HOST_PORT" -ge 1024 ] || { echo -e "${RED}❌ Port must be >= 1024.${NC}"; TCP_HOST_PORT=2222; }

    echo ""
    echo -e "${YELLOW}⏳ Background core dependencies install ho rahi hain... Please wait.${NC}"
    echo ""

    install_deps_silent

    mkdir -p "$VPS_DIR/$VM_NAME" "$BASE_DIR"
    BASE_IMAGE="$BASE_DIR/jammy-base.qcow2"
    DISK_IMAGE="$VPS_DIR/$VM_NAME/disk.qcow2"

    if [ ! -f "$BASE_IMAGE" ]; then
        echo -e "${YELLOW}📥 Downloading Ubuntu 22.04 Cloud Image (once)...${NC}"
        wget -q --show-progress https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O "$BASE_IMAGE"
        chmod 600 "$BASE_IMAGE"
    else
        echo -e "${GREEN}✅ Base Image Cache Detected at $BASE_IMAGE.${NC}"
    fi

    loading_bar "Generating Cloud-Init Matrix"
    cat > "$VPS_DIR/$VM_NAME/user-data" <<EOF
#cloud-config
users:
  - name: ${USER_NAME}
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    plain_text_passwd: ${USER_PASS}
    shell: /bin/bash
ssh_pwauth: True
chpasswd:
  list: |
    ${USER_NAME}:${USER_PASS}
  expire: False
runcmd:
  - [sh, -c, "echo '0 3 * * * root /sbin/fstrim -a >/dev/null 2>&1' > /etc/cron.d/fstrim"]
EOF
    if [ -n "$SSH_KEY" ]; then
        cat >> "$VPS_DIR/$VM_NAME/user-data" <<EOF

ssh_authorized_keys:
  - ${SSH_KEY}
EOF
    fi
    cloud-localds "$VPS_DIR/$VM_NAME/seed.img" "$VPS_DIR/$VM_NAME/user-data" > /dev/null 2>&1
    chmod 600 "$VPS_DIR/$VM_NAME/seed.img"

    loading_bar "Allocating Server Hard Disk (${DISK_GB}G)"
    if [ -f "$DISK_IMAGE" ]; then
        rm -f "$DISK_IMAGE"
    fi
    qemu-img create -f qcow2 -b "$BASE_IMAGE" -F qcow2 "$DISK_IMAGE" ${DISK_GB}G > /dev/null 2>&1
    chmod 600 "$DISK_IMAGE"

    save_env
    write_scripts
    start_vm
    start_tunnels
    echo ""
    read -p "Press Enter to return to dashboard..." _
    show_menu
}

save_env() {
    cat > "$VPS_DIR/$VM_NAME/.vps_env" <<EOF
VM_NAME=${VM_NAME}
DISK_IMAGE=${DISK_IMAGE}
RAM_GB=${RAM_GB}
CPU_CORES=${CPU_CORES}
DISK_GB=${DISK_GB}
TCP_HOST_PORT=${TCP_HOST_PORT}
TCP_GUEST_PORT=${TCP_GUEST_PORT}
USER_NAME=${USER_NAME}
USER_PASS=${USER_PASS}
EOF
}

# Generate self-contained start/stop/tunnel/supervisor scripts
write_scripts() {
    VDIR="$VPS_DIR/$VM_NAME"

    # ----- start.sh : boot the VM daemonized with all perf opts -----
    cat > "$VDIR/start.sh" <<EOF
#!/usr/bin/env bash
source "$VDIR/.vps_env"
export PATH="\$PATH:/usr/bin:/usr/local/bin"

if [ -f "$VDIR/vm.pid" ] && kill -0 "\$(cat "$VDIR/vm.pid")" 2>/dev/null; then
    echo "VM already running."; exit 0
fi

# Refuse to start if the host port is already taken
if ss -ltn 2>/dev/null | awk '{print \$4}' | grep -qE ":\${TCP_HOST_PORT}\$"; then
    echo "ERROR: port \${TCP_HOST_PORT} already in use. Stop that process or pick another port."
    exit 1
fi

# Auto-select accelerator + CPU model.
# /dev/kvm may EXIST but not be openable (containers often block it), so we
# actually try to open it rather than just checking for the node.
KVM_OK=0
if [ -e /dev/kvm ] && exec 3<>/dev/kvm 2>/dev/null; then
    exec 3>&- 3<&-
    KVM_OK=1
fi
QEMU_ACCEL="-enable-kvm"
QEMU_CPU="-cpu host"
if [ "\$KVM_OK" != "1" ]; then
    QEMU_ACCEL="-accel tcg,thread=multi,tb-size=1024"
    QEMU_CPU="-cpu max"
fi

# Rotate logs (keep 1 old copy so we don't grow forever)
[ -f "$VDIR/serial.log" ] && mv "$VDIR/serial.log" "$VDIR/serial.log.1" 2>/dev/null
[ -f "$VDIR/qemu.log" ]   && mv "$VDIR/qemu.log"   "$VDIR/qemu.log.1"   2>/dev/null

# virtio disk + NIC (much faster than emulated e1000/ide),
# cache=writeback + discard=unmap so guest fstrim shrinks the qcow2 on the host.
qemu-system-x86_64 \\
    -drive file="\$DISK_IMAGE",format=qcow2,if=virtio,cache=writeback,discard=unmap \\
    -m "\${RAM_GB}G" \\
    -smp "\${CPU_CORES}" \\
    -drive file="$VDIR/seed.img",format=raw,if=virtio,readonly=on \\
    -display none \\
    -monitor none \\
    -serial file:"$VDIR/serial.log" \\
    \$QEMU_ACCEL \$QEMU_CPU \\
    -netdev user,id=net0,hostfwd=tcp::\${TCP_HOST_PORT}-:\${TCP_GUEST_PORT} \\
    -device virtio-net-pci,netdev=net0 \\
    -daemonize \\
    -pidfile "$VDIR/vm.pid" \\
    >> "$VDIR/qemu.log" 2>&1

echo "VM started (PID \$(cat "$VDIR/vm.pid" 2>/dev/null))."
EOF
    chmod +x "$VDIR/start.sh"

    # ----- stop.sh : stop the VM -----
    cat > "$VDIR/stop.sh" <<EOF
#!/usr/bin/env bash
if [ -f "$VDIR/vm.pid" ]; then
    PID=\$(cat "$VDIR/vm.pid")
    if kill -0 "\$PID" 2>/dev/null; then
        kill "\$PID" 2>/dev/null
        sleep 3
        kill -9 "\$PID" 2>/dev/null || true
        echo "VM stopped."
    else
        echo "VM not running."
    fi
    rm -f "$VDIR/vm.pid"
fi
EOF
    chmod +x "$VDIR/stop.sh"

    # ----- tunnel.sh : manage BOTH sshx + cloudflared tunnels -----
    cat > "$VDIR/tunnel.sh" <<EOF
#!/usr/bin/env bash
source "$VDIR/.vps_env"
export PATH="\$PATH:/usr/bin:/usr/local/bin"
CMD="\${1:-start}"

case "\$CMD" in
  start)
    # --- SSHX web terminal ---
    if [ -f "$VDIR/sshx.pid" ] && kill -0 "\$(cat "$VDIR/sshx.pid")" 2>/dev/null; then
        echo "sshx already running."
    else
        nohup setsid sh -c "curl -sSf https://sshx.io/get | sh -s run" \\
            </dev/null > "$VDIR/sshx.log" 2>&1 &
        echo \$! > "$VDIR/sshx.pid"
        echo "sshx tunnel starting..."
    fi

    # --- Cloudflare TCP tunnel (reverse SSH) ---
    if [ -f "$VDIR/cf.pid" ] && kill -0 "\$(cat "$VDIR/cf.pid")" 2>/dev/null; then
        echo "cloudflared already running."
    elif command -v cloudflared > /dev/null 2>&1; then
        nohup setsid cloudflared tunnel --url tcp://localhost:\${TCP_HOST_PORT} \\
            --no-autoupdate --loglevel info \\
            </dev/null > "$VDIR/cf.log" 2>&1 &
        echo \$! > "$VDIR/cf.pid"
        echo "cloudflared tunnel starting..."
        # Background poller: grab the trycloudflare hostname as soon as it
        # appears and write it to connect.txt. Does NOT block the dashboard.
        # Excludes api.trycloudflare.com (cloudflared's API endpoint).
        (
            for i in \$(seq 1 180); do
                if [ -f "$VDIR/cf.pid" ] && kill -0 "\$(cat "$VDIR/cf.pid")" 2>/dev/null; then
                    H=\$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$VDIR/cf.log" 2>/dev/null \\
                        | grep -v 'https://api\.trycloudflare\.com' | head -n1 | sed 's|https://||')
                    [ -n "\$H" ] && { echo "\$H" > "$VDIR/connect.txt"; exit 0; }
                    sleep 1
                else
                    echo "cloudflared exited before a hostname was assigned." >> "$VDIR/cf.log"
                    exit 1
                fi
            done
            echo "Timed out waiting for Cloudflare hostname." >> "$VDIR/cf.log"
            exit 1
        ) &
        # Don't wait — return to the menu immediately; status shows the URL once ready.
    else
        echo "cloudflared not installed. Run Option 1 (Install Dependencies) first."
    fi
    ;;
  stop)
    [ -f "$VDIR/sshx.pid" ] && kill "\$(cat "$VDIR/sshx.pid")" 2>/dev/null
    [ -f "$VDIR/cf.pid" ]   && kill "\$(cat "$VDIR/cf.pid")"   2>/dev/null
    pkill -f "cloudflared tunnel --url tcp://localhost:\${TCP_HOST_PORT}" 2>/dev/null || true
    rm -f "$VDIR/sshx.pid" "$VDIR/cf.pid" "$VDIR/connect.txt"
    echo "Tunnels stopped."
    ;;
  status)
    [ -f "$VDIR/cf.pid" ] && kill -0 "\$(cat "$VDIR/cf.pid")" 2>/dev/null && echo "cloudflared: RUNNING" || echo "cloudflared: stopped"
    [ -f "$VDIR/sshx.pid" ] && kill -0 "\$(cat "$VDIR/sshx.pid")" 2>/dev/null && echo "sshx: RUNNING" || echo "sshx: stopped"
    ;;
esac
EOF
    chmod +x "$VDIR/tunnel.sh"

    # ----- supervisor.sh : auto-restart VM + tunnels if they die (24/7) -----
    cat > "$VDIR/supervisor.sh" <<EOF
#!/usr/bin/env bash
cd "$VDIR" || exit 1
source "$VDIR/.vps_env"
export PATH="\$PATH:/usr/bin:/usr/local/bin"
while true; do
    if [ -f "$VDIR/vm.pid" ] && kill -0 "\$(cat "$VDIR/vm.pid")" 2>/dev/null; then
        :
    else
        echo "\$(date '+%F %T') VM down -> restarting" >> "$VDIR/supervisor.log"
        "$VDIR/start.sh" >> "$VDIR/supervisor.log" 2>&1
        sleep 5
    fi
    if [ -f "$VDIR/cf.pid" ] && kill -0 "\$(cat "$VDIR/cf.pid")" 2>/dev/null; then
        :
    else
        echo "\$(date '+%F %T') tunnel down -> restarting" >> "$VDIR/supervisor.log"
        "$VDIR/tunnel.sh" start >> "$VDIR/supervisor.log" 2>&1
    fi
    sleep 15
done
EOF
    chmod +x "$VDIR/supervisor.sh"

    # ----- autostart.sh : launcher for @reboot cron -----
    cat > "$VDIR/autostart.sh" <<EOF
#!/usr/bin/env bash
cd "$VDIR" || exit 1
setsid ./supervisor.sh >/dev/null 2>&1 &
echo "Autostart launched supervisor for $VM_NAME."
EOF
    chmod +x "$VDIR/autostart.sh"
}

# ==========================================
# STEP 2: START VM (daemonized, survives SSH logout)
# ==========================================
start_vm() {
    clear
    echo -e "${GREEN}==========================================================${NC}"
    type_effect "👹 DATA SYSTEM SYNCHRONIZED! PIPING TERMINAL CHANNELS..." 0.02
    echo -e "${GREEN}==========================================================${NC}"
    echo ""
    "$VPS_DIR/$VM_NAME/start.sh"
    loading_bar "Booting QEMU Accelerated VM Instance"
}

# ==========================================
# STEP 3: TUNNELS (sshx + cloudflare), survive logout
# ==========================================
start_tunnels() {
    echo -e "${YELLOW}📡 Launching SSHX + Cloudflare public tunnels...${NC}"
    "$VPS_DIR/$VM_NAME/tunnel.sh" start
    show_connect_info
}

stop_tunnels() {
    "$VPS_DIR/$VM_NAME/tunnel.sh" stop > /dev/null 2>&1
}

# ==========================================
# STEP 4: STATUS & CONNECT INFO
# ==========================================
show_connect_info() {
    CF_HOST=$(cat "$VPS_DIR/$VM_NAME/connect.txt" 2>/dev/null || true)
    SSHX_URL=$(grep -oE 'https://sshx\.io/s/[a-zA-Z0-9_-]+' "$VPS_DIR/$VM_NAME/sshx.log" 2>/dev/null | head -n1)
    echo ""
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "🎉       KVM VPS - VIRTUAL MACHINE NETWORK ACTIVE        "
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${WHITE}🖥️  VM Name   : ${CYAN}${VM_NAME}${NC}"
    echo -e "${WHITE}👤 Username  : ${CYAN}${USER_NAME}${NC}"
    echo -e "${WHITE}🔑 Password  : ${CYAN}${USER_PASS}${NC}"
    echo -e "${WHITE}⚙️  Resources : ${CYAN}${RAM_GB}G RAM | ${CPU_CORES} Cores | ${DISK_GB}G Disk${NC}"
    echo -e "${RED}----------------------------------------------------------${NC}"
    echo -e "${WHITE}🔌 Local SSH  : ssh ${USER_NAME}@localhost -p ${TCP_HOST_PORT}${NC}"
    if [ -n "$CF_HOST" ]; then
        echo -e "${RED}----------------------------------------------------------${NC}"
        echo -e "${YELLOW}🌩️  CLOUDFLARE REVERSE SSH (works from anywhere):${NC}"
        echo -e "${GREEN}  Terminal 1: cloudflared access tcp --hostname ${CF_HOST} --url localhost:${TCP_HOST_PORT}${NC}"
        echo -e "${GREEN}  Terminal 2: ssh ${USER_NAME}@localhost -p ${TCP_HOST_PORT}${NC}"
    else
        echo -e "${YELLOW}  🌩️  Cloudflare tunnel still connecting... run '${NC}${CYAN}tunnel.sh start${NC}${YELLOW}' to retry.${NC}"
    fi
    if [ -n "$SSHX_URL" ]; then
        echo -e "${RED}----------------------------------------------------------${NC}"
        echo -e "${YELLOW}🔥 SSHX WEB TERMINAL (Copy & Paste in Browser):${NC}"
        echo -e "${GREEN}👉 $SSHX_URL 👈${NC}"
    fi
    echo -e "${GREEN}==========================================================${NC}"
}

vps_status() {
    clear
    echo -e "${GREEN}==========================================================${NC}"
    echo -e "${WHITE}📋 VIRTUAL MACHINE INVENTORY${NC}"
    echo -e "${GREEN}==========================================================${NC}"
    echo ""
    found=0
    for env in "$VPS_DIR"/*/.vps_env; do
        [ -f "$env" ] || continue
        found=1
        unset VM_NAME RAM_GB CPU_CORES DISK_GB USER_NAME USER_PASS TCP_HOST_PORT
        source "$env"
        if vm_running; then
            echo -e "  ${GREEN}●${NC} ${CYAN}${VM_NAME}${NC} — RUNNING  (port ${TCP_HOST_PORT}, ${RAM_GB}G/${CPU_CORES}c)"
        else
            echo -e "  ${RED}○${NC} ${CYAN}${VM_NAME}${NC} — STOPPED  (port ${TCP_HOST_PORT}, ${RAM_GB}G/${CPU_CORES}c)"
        fi
    done
    [ "$found" -eq 0 ] && echo -e "${RED}  No VMs found. Build one using Option 2.${NC}"
    echo ""
    if select_vm "🔹 Select a VM for connect info:"; then
        source "$VPS_DIR/$VM_NAME/.vps_env"
        show_connect_info
    fi
    echo ""
    read -p "Press Enter to return to dashboard..." _
    show_menu
}

# ==========================================
# STEP 5: RESTART / STOP / REMOVE
# ==========================================
restart_vps() {
    echo ""
    if ! select_vm "🔹 Select a VM to restart:"; then sleep 2; show_menu; fi
    source "$VPS_DIR/$VM_NAME/.vps_env"
    # Kill supervisor so it doesn't fight us during restart
    pkill -f "$VPS_DIR/$VM_NAME/supervisor.sh" 2>/dev/null || true
    "$VPS_DIR/$VM_NAME/stop.sh"
    stop_tunnels
    sleep 2
    start_vm
    start_tunnels
    echo ""
    read -p "Press Enter to return to dashboard..." _
    show_menu
}

stop_vps() {
    echo ""
    if ! select_vm "🔹 Select a VM to stop:"; then sleep 2; show_menu; fi
    source "$VPS_DIR/$VM_NAME/.vps_env"
    pkill -f "$VPS_DIR/$VM_NAME/supervisor.sh" 2>/dev/null || true
    stop_tunnels
    "$VPS_DIR/$VM_NAME/stop.sh"
    echo ""
    read -p "Press Enter to return to dashboard..." _
    show_menu
}

remove_vps() {
    echo ""
    if ! select_vm "🔹 Select a VM to remove:"; then sleep 2; show_menu; fi
    pkill -f "$VPS_DIR/$VM_NAME/supervisor.sh" 2>/dev/null || true
    if [ -f "$VPS_DIR/$VM_NAME/stop.sh" ]; then "$VPS_DIR/$VM_NAME/stop.sh"; fi
    stop_tunnels
    disable_autostart > /dev/null 2>&1
    rm -rf "$VPS_DIR/$VM_NAME"
    echo -e "${GREEN}✅ VM '$VM_NAME' removed successfully!${NC}"
    echo ""
    read -p "Press Enter to return to dashboard..." _
    show_menu
}

# ==========================================
# STEP 6: AUTOSTART ON BOOT (cron @reboot -> supervisor)
# ==========================================
enable_autostart() {
    START_SCRIPT="$VPS_DIR/$VM_NAME/autostart.sh"
    if ! crontab -l 2>/dev/null | grep -qF "$START_SCRIPT"; then
        ( crontab -l 2>/dev/null; echo "@reboot sleep 10 && bash $START_SCRIPT >> $VPS_DIR/$VM_NAME/autostart.log 2>&1" ) | crontab -
        echo -e "${GREEN}✅ Autostart ENABLED for '$VM_NAME' (supervisor restarts VM+tunnels on boot & crash).${NC}"
        # launch supervisor now too so crash-restart is active immediately
        pkill -f "$VPS_DIR/$VM_NAME/supervisor.sh" 2>/dev/null || true
        "$VPS_DIR/$VM_NAME/autostart.sh"
    else
        echo -e "${YELLOW}⚠️  Autostart already enabled for '$VM_NAME'.${NC}"
    fi
}

disable_autostart() {
    crontab -l 2>/dev/null | grep -vF "$VPS_DIR/$VM_NAME/autostart.sh" | crontab - 2>/dev/null || true
    pkill -f "$VPS_DIR/$VM_NAME/supervisor.sh" 2>/dev/null || true
    echo -e "${GREEN}✅ Autostart DISABLED (supervisor stopped).${NC}"
}

toggle_autostart() {
    echo ""
    if ! select_vm "🔹 Select a VM to toggle autostart:"; then sleep 2; show_menu; fi
    source "$VPS_DIR/$VM_NAME/.vps_env"
    if crontab -l 2>/dev/null | grep -qF "$VPS_DIR/$VM_NAME/autostart.sh"; then
        disable_autostart
    else
        enable_autostart
    fi
    echo ""
    read -p "Press Enter to return to dashboard..." _
    show_menu
}

# EXECUTE TRIGGER
show_menu
