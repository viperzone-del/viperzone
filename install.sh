#!/bin/bash

# Color Definitions
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

set -e
export DEBIAN_FRONTEND=noninteractive
clear

# Function for animated loading indicator
run_task() {
    local message="$1"
    local command="$2"
    
    echo -ne "${CYAN}[>] ${message}...${RESET}"
    
    # Run command silently in background
    eval "$command" > /dev/null 2>&1 &
    local pid=$!
    
    # Loading animation loops while command runs
    local spin='-\|/'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        echo -ne "\b${spin:$i:1}"
        sleep 0.1
    done
    
    # Check exit status
    wait $pid
    if [ $? -eq 0 ]; then
        echo -e "\b${GREEN}[DONE]${RESET}"
    else
        echo -e "\b${RED}[FAILED]${RESET}"
        exit 1
    fi
}

echo -e "${GREEN}"
echo "██╗   ██╗██╗██████╗ ███████╗██████╗     ███████╗ ██████╗ ███╗   ██╗███████╗"
echo "██║   ██║██║██╔══██╗██╔════╝██╔══██╗    ╚══███╔╝██╔═══██╗████╗  ██║██╔════╝"
echo "██║   ██║██║██████╔╝█████╗  ██████╔╝      ███╔╝ ██║   ██║██╔██╗ ██║█████╗  "
echo "╚██╗ ██╔╝██║██╔═══╝ ██╔══╝  ██╔══██╗     ███╔╝  ██║   ██║██║╚██╗██║██╔══╝  "
echo " ╚████╔╝ ██║██║     ███████╗██║  ██║    ███████╗╚██████╔╝██║ ╚████║███████╗"
echo "  ╚═══╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝    ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝"
echo "=========================================================================="
echo "                   CLOUD9 IDE - SYSTEM RECON & OVERRIDE                   "
echo "=========================================================================="
echo -e "${RESET}"

############################################
# ROOT & OS CHECK
############################################
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[!] ACCESS DENIED: Please escalate to root (sudo bash)${RESET}\n"
    exit 1
fi

UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "Unknown")
if [[ "$UBUNTU_VERSION" != "22.04" && "$UBUNTU_VERSION" != "24.04" ]]; then
    echo -e "${RED}[!] ERROR: Target OS Architecture ($UBUNTU_VERSION) unsupported.${RESET}\n"
    exit 1
fi

############################################
# INTERACTIVE BUYER INPUT
############################################
echo -e "${YELLOW}[?] CUSTOMER INTAKE PROTOCOL:${RESET}"
read -p "    Input Buyer Name (Username Telegram): " BUYER_NAME
if [ -z "$BUYER_NAME" ]; then
    BUYER_NAME="@unknown_buyer"
fi
echo ""

############################################
# AUTOMATIC TELEGRAM VARIABLE CAPTURE
############################################
TG_TOKEN="${TOKEN:-}"
TG_CHAT_ID="${CHAT_ID:-}"

echo -e "${GREEN}[+] Target System Identified: Ubuntu $UBUNTU_VERSION${RESET}"
if [ -n "$TG_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
    echo -e "${GREEN}[+] Telegram Payload Mode: ENABLED (Creds detected)${RESET}"
else
    echo -e "${YELLOW}[!] Telegram Payload Mode: DISABLED (Run with variables to enable)${RESET}"
fi
echo -e "${GREEN}[+] Initializing Payload Injection...${RESET}\n"

############################################
# CONFIGURATION
############################################
CONTAINER_NAME="cloud9"
PORT="8181"
INTERNAL_PORT="8182"
WORKSPACE="/root/workspace"
TIMEZONE="Asia/Jakarta"

CUSTOM_USER="Viper"
CUSTOM_PASS="viperzone99!"

############################################
# EXECUTION MATRIX (SILENT RUN)
############################################

run_task "Purging old core repositories" \
"rm -f /etc/apt/sources.list.d/docker*.list /etc/apt/sources.list.d/nodesource.list && apt update -y"

run_task "Synchronizing system packages" \
"apt upgrade -y"

run_task "Injecting required network dependencies" \
"apt install -y curl wget git zip unzip openssl ca-certificates gnupg lsb-release ufw iptables nginx apache2-utils"

run_task "Bypassing firewall vectors (Port ${PORT})" \
"ufw allow ${PORT}/tcp || true && iptables -I INPUT -p tcp --dport ${PORT} -j ACCEPT || true"

run_task "Deploying Docker Main Engine" \
"if ! command -v docker >/dev/null 2>&1; then curl -fsSL https://get.docker.com | sh; fi && systemctl enable docker && systemctl start docker"

run_task "Allocating secure environment space" \
"mkdir -p ${WORKSPACE}"

run_task "Terminating previous instances" \
"docker rm -f ${CONTAINER_NAME} >/dev/null 2>&1 || true && rm -f /etc/nginx/sites-enabled/cloud9 /etc/nginx/sites-available/cloud9"

run_task "Downloading fresh Cloud9 Binary Matrix" \
"docker pull lscr.io/linuxserver/cloud9:latest"

run_task "Spawning isolated sandbox container" \
"docker run -d --name ${CONTAINER_NAME} -e PUID=0 -e PGID=0 -e TZ=${TIMEZONE} -p 127.0.0.1:${INTERNAL_PORT}:8000 -v ${WORKSPACE}:/code --restart unless-stopped lscr.io/linuxserver/cloud9:latest"

run_task "Locking down Gateway Proxy via Nginx" \
"mkdir -p /etc/nginx/auth && \
htpasswd -b -c /etc/nginx/auth/.cloud9_htpasswd '${CUSTOM_USER}' '${CUSTOM_PASS}' && \
cat << 'EOF' > /etc/nginx/sites-available/cloud9
server {
    listen NGINX_PORT;
    server_name _;
    auth_basic \"Viper Zone - System Lockdown\";
    auth_basic_user_file /etc/nginx/auth/.cloud9_htpasswd;
    location / {
        proxy_pass http://127.0.0.1:INTERNAL_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";
        proxy_read_timeout 86400;
    }
}
EOF
sed -i 's/NGINX_PORT/'${PORT}'/g' /etc/nginx/sites-available/cloud9 && \
sed -i 's/INTERNAL_PORT/'${INTERNAL_PORT}'/g' /etc/nginx/sites-available/cloud9 && \
ln -sf /etc/nginx/sites-available/cloud9 /etc/nginx/sites-enabled/ && \
systemctl restart nginx"

run_task "Stabilizing environment protocols" \
"sleep 15"

# --- DIRECT EXECUTION (ANTI-HANG SUB-PROCESS) ---

echo -ne "${CYAN}[>] Compiling Backend Core (PHP, Python3, Git)...${RESET}"
docker exec ${CONTAINER_NAME} bash -c 'export DEBIAN_FRONTEND=noninteractive && apt update -y && apt install -y php php-cli php-curl php-mbstring php-xml php-zip php-mysql python3 python3-pip git curl wget zip unzip' > /dev/null 2>&1 || true
echo -e "\b${GREEN}[DONE]${RESET}"

echo -ne "${CYAN}[>] Injecting Node.js runtime environment (v18)...${RESET}"
docker exec ${CONTAINER_NAME} bash -c 'cd /tmp && curl -fsSL https://nodejs.org/dist/v18.20.8/node-v18.20.8-linux-x64.tar.xz -o node.tar.xz && tar -xf node.tar.xz && mv node-v18.20.8-linux-x64 /opt/nodejs && ln -sf /opt/nodejs/bin/node /usr/local/bin/node && ln -sf /opt/nodejs/bin/npm /usr/local/bin/npm && ln -sf /opt/nodejs/bin/npx /usr/local/bin/npx && rm -f node.tar.xz' > /dev/null 2>&1 || true
echo -e "\b${GREEN}[DONE]${RESET}"

echo -ne "${CYAN}[>] Deploying dependency manager (Composer)...${RESET}"
docker exec ${CONTAINER_NAME} bash -c 'php -r "copy(\"https://getcomposer.org/installer\",\"composer-setup.php\");" && php composer-setup.php --install-dir=/usr/local/bin --filename=composer && rm -f composer-setup.php' > /dev/null 2>&1 || true
echo -e "\b${GREEN}[DONE]${RESET}"

############################################
# WARRANTY & TIME LOGIC
############################################
export LC_TIME="id_ID.UTF-8"
START_WARRANTY=$(TZ="Asia/Jakarta" date +"%A, %d %B %Y (%H:%M WIB)")
END_WARRANTY=$(TZ="Asia/Jakarta" date -d "+14 days" +"%A, %d %B %Y (%H:%M WIB)")

SERVER_IP=$(curl -4 -s ifconfig.me || hostname -I | awk '{print $1}')

############################################
# TELEGRAM NOTIFICATION DISPATCH (HTML MODE)
############################################
if [ -n "$TG_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
    TG_MESSAGE="⚡ <b>VIPER ZONE CLOUD IDE DEPLOYED</b> ⚡%0A%0A"
    TG_MESSAGE+="🛡️ <b>Aktivasi</b> : ${START_WARRANTY}%0A"
    TG_MESSAGE+="⏳ <b>Expired Garansi</b> : ${END_WARRANTY} <i>(14 Hari Full)</i>%0A%0A"
    TG_MESSAGE+="👤 <b>Member</b> : ${BUYER_NAME}%0A"
    TG_MESSAGE+="🖥️ <b>Host IP</b> : <code>${SERVER_IP}</code>%0A"
    TG_MESSAGE+="🌐 <b>URL</b> : http://${SERVER_IP}:${PORT}%0A"
    TG_MESSAGE+="👤 <b>Username</b> : <code>${CUSTOM_USER}</code>%0A"
    TG_MESSAGE+="🔑 <b>Password</b> : <code>${CUSTOM_PASS}</code>%0A%0A"
    TG_MESSAGE+="📢 <b>Telegram Support</b> : @admviper_cloud%0A%0A"
    TG_MESSAGE+="⚠️ <i>Garansi ganti baru 100% jika terjadi kendala system.</i>"

    curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        -d "text=${TG_MESSAGE}" \
        -d "parse_mode=HTML" > /dev/null 2>&1 || true
fi

############################################
# HACKER STYLE OUTPUT OVERRIDE
############################################
clear
echo -e "${GREEN}"
echo "/////////////////////////////DONE/////////////////////////"
echo "██╗   ██╗██╗██████╗ ███████╗██████╗     ███████╗ ██████╗ ███╗   ██╗███████╗"
echo "██║   ██║██║██╔══██╗██╔════╝██╔══██╗    ╚══███╔╝██╔═══██╗████╗  ██║██╔════╝"
echo "██║   ██║██║██████╔╝█████╗  ██████╔╝      ███╔╝ ██║   ██║██╔██╗ ██║█████╗  "
echo "╚██╗ ██╔╝██║██╔═══╝ ██╔══╝  ██╔══██╗     ███╔╝  ██║   ██║██║╚██╗██║██╔══╝  "
echo " ╚████╔╝ ██║██║     ███████╗██║  ██║    ███████╗╚██████╔╝██║ ╚████║███████╗"
echo "  ╚═══╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝    ╚══════╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝"
echo "                  VIPER ZONE CLOUD Telegram :  @admviper_cloud              "
echo "///////////////////////////////////////////////////////////"
echo ""
if [ -n "$TG_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
    echo -e "${CYAN}  [⚡] Telegram Notification Dispatch: [SUCCESS]${RESET}\n"
fi
echo -e "${YELLOW}  [+] BUYER      : ${BUYER_NAME}"
echo -e "${YELLOW}  [+] AKTIVASI   : ${START_WARRANTY}"
echo -e "${YELLOW}  [+] GARANSI    : s/d ${END_WARRANTY} (14 Hari Ganti Baru Full)"
echo -e "${YELLOW}  [+] URL        : http://${SERVER_IP}:${PORT}"
echo -e "${YELLOW}  [+] Username   : ${CUSTOM_USER}"
echo -e "${YELLOW}  [+] Password   : ${CUSTOM_PASS}"
echo ""
echo -e "${GREEN}////////////////////////////THANKS//////////////////////${RESET}"
echo ""
