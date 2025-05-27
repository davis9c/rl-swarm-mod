#!/bin/bash

set -euo pipefail

# Argumen umum
ROOT=$PWD

# Ekspor variabel lingkungan yang diperlukan
export IDENTITY_PATH
export CONNECT_TO_TESTNET
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120  # 2 menit

# Periksa apakah alamat multi publik diberikan, jika tidak gunakan default
DEFAULT_PUB_MULTI_ADDRS=""
PUB_MULTI_ADDRS=${PUB_MULTI_ADDRS:-$DEFAULT_PUB_MULTI_ADDRS}

# Periksa apakah alamat multi peer diberikan, jika tidak gunakan default
DEFAULT_PEER_MULTI_ADDRS="" # node koordinator gensyn
PEER_MULTI_ADDRS=${PEER_MULTI_ADDRS:-$DEFAULT_PEER_MULTI_ADDRS}

# Periksa apakah alamat multi host diberikan, jika tidak gunakan default
DEFAULT_HOST_MULTI_ADDRS="/ip4/0.0.0.0/tcp/38331"
HOST_MULTI_ADDRS=${HOST_MULTI_ADDRS:-$DEFAULT_HOST_MULTI_ADDRS}

# Jalur ke kunci privat RSA. Jika jalur ini tidak ada, pasangan kunci baru akan dibuat.
# Hapus file ini jika Anda menginginkan PeerID baru.
DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

SMALL_SWARM_CONTRACT="0x69C6e1D608ec64885E7b185d39b04B491a71768C"
BIG_SWARM_CONTRACT="0x6947c6E196a48B77eFa9331EC1E3e45f3Ee5Fd58"

# Akan mengabaikan GPU yang terlihat jika disetel.
CPU_ONLY=${CPU_ONLY:-""}

# Disetel jika berhasil diparsing dari modal-login/temp-data/userData.json.
ORG_ID=${ORG_ID:-""}

GREEN_TEXT="\033[32m"
BLUE_TEXT="\033[34m"
RESET_TEXT="\033[0m"

echo_green() {
    echo -e "$GREEN_TEXT$1$RESET_TEXT"
}

echo_blue() {
    echo -e "$BLUE_TEXT$1$RESET_TEXT"
}

ROOT_DIR="$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)"

# Fungsi untuk membersihkan proses server saat keluar
cleanup() {
    echo_green ">> Mematikan pelatih..."

    # Hapus kredensial modal jika ada
    rm -r $ROOT_DIR/modal-login/temp-data/*.json 2> /dev/null || true

    # Bunuh semua proses yang menjadi milik grup proses skrip ini
    kill -- -$$ || true

    exit 0
}

trap cleanup EXIT

echo_step() {
    echo -e "\n${BLUE_TEXT}[Tahap $1/${TOTAL_STEPS}] $2${RESET_TEXT}"
}

TOTAL_STEPS=7

# Menampilkan banner
echo_step "1" "Memulai RL-Swarm"
echo -e "\033[38;5;224m"
cat << "EOF"
    ██████  ██            ███████ ██     ██  █████  ██████  ███    ███
    ██   ██ ██            ██      ██     ██ ██   ██ ██   ██ ████  ████
    ██████  ██      █████ ███████ ██  █  ██ ███████ ██████  ██ ████ ██
    ██   ██ ██                 ██ ██ ███ ██ ██   ██ ██   ██ ██  ██  ██
    ██   ██ ███████       ███████  ███ ███  ██   ██ ██   ██ ██      ██

    Dari Gensyn

EOF

BYPASS=true
if [ "$BYPASS" = true ]; then
    CONNECT_TO_TESTNET=true
    USE_BIG_SWARM=false
    PARAM_B="0.5"
else
    while true; do
        echo -en $GREEN_TEXT
        read -p ">> Apakah Anda ingin terhubung ke Testnet? [Y/n] " yn
        echo -en $RESET_TEXT
        yn=${yn:-Y}  # Default ke "Y" jika user menekan Enter
        case $yn in
            [Yy]*)  CONNECT_TO_TESTNET=true && break ;;
            [Nn]*)  CONNECT_TO_TESTNET=false && break ;;
            *)  echo ">>> Mohon jawab ya atau tidak." ;;
        esac
    done

    while true; do
        echo -en $GREEN_TEXT
        read -p ">> Pilih swarm yang ingin diikuti (Matematika Dasar (A) atau Matematika Lanjut (B))? [A/b] " ab
        echo -en $RESET_TEXT
        ab=${ab:-A}  # Default ke "A" jika user menekan Enter
        case $ab in
            [Aa*)  USE_BIG_SWARM=false && break ;;
            [Bb]*)  USE_BIG_SWARM=true && break ;;
            *)  echo ">>> Mohon pilih A atau B." ;;
        esac
    done
fi
if [ "$USE_BIG_SWARM" = true ]; then
    SWARM_CONTRACT="$BIG_SWARM_CONTRACT"
else
    SWARM_CONTRACT="$SMALL_SWARM_CONTRACT"
fi
if [ "$BYPASS" = true ]; then
    PARAM_B="0.5"
else
    while true; do
        echo -en $GREEN_TEXT
        read -p ">> Berapa parameter yang diinginkan (dalam milyar)? [0.5, 1.5, 7, 32, 72] " pc
        echo -en $RESET_TEXT
        pc=${pc:-0.5}  # Default ke "0.5" jika user menekan Enter
        case $pc in
            0.5 | 1.5 | 7 | 32 | 72) PARAM_B=$pc && break ;;
            *)  echo ">>> Mohon pilih dari [0.5, 1.5, 7, 32, 72]." ;;
        esac
    done
fi

if [ "$CONNECT_TO_TESTNET" = true ]; then
    # Jalankan server modal_login.
    echo "Silakan masuk untuk membuat Dompet Server Ethereum"
    cd modal-login
    # Periksa apakah perintah yarn ada; jika tidak, instal Yarn.

    # Pengaturan Node.js + NVM
    if ! command -v node > /dev/null 2>&1; then
        echo "Node.js tidak ditemukan. Menginstal NVM dan Node.js versi terbaru..."
        export NVM_DIR="$HOME/.nvm"
        if [ ! -d "$NVM_DIR" ]; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        fi
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        nvm install node
    else
        echo "Node.js sudah terinstal: $(node -v)"
    fi

    if ! command -v yarn > /dev/null 2>&1; then
        # Deteksi Ubuntu (termasuk WSL Ubuntu) dan instal Yarn sesuai
        if grep -qi "ubuntu" /etc/os-release 2> /dev/null || uname -r | grep -qi "microsoft"; then
            echo "Mendeteksi Ubuntu atau WSL Ubuntu. Menginstal Yarn melalui apt..."
            curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
            echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
            sudo apt update && sudo apt install -y yarn
        else
            echo "Yarn tidak ditemukan. Menginstal Yarn secara global dengan npm (tanpa pengeditan profil)…"
            # Ini mendarat di $NVM_DIR/versions/node/<ver>/bin yang sudah ada di PATH
            npm install -g --silent yarn
        fi
    fi
    yarn install
    yarn dev > /dev/null 2>&1 & # Jalankan di latar belakang dan sembunyikan output

    SERVER_PID=$!  # Simpan ID proses
    echo "Proses server yang dimulai: $SERVER_PID"
    sleep 5

    # Coba buka URL di browser default
    if open http://localhost:3000 2> /dev/null; then
        echo_green ">> Berhasil membuka http://localhost:3000 di browser default Anda."
    else
        echo ">> Gagal membuka http://localhost:3000. Silakan buka secara manual."
    fi

    cd ..

    echo_green ">> Menunggu modal userData.json dibuat..."
    while [ ! -f "modal-login/temp-data/userData.json" ]; do
        sleep 5  # Tunggu 5 detik sebelum memeriksa lagi
    done
    echo "Ditemukan userData.json. Melanjutkan..."

    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo "ORG_ID Anda disetel ke: $ORG_ID"

    # Tunggu sampai kunci API diaktifkan oleh klien
    echo "Menunggu kunci API diaktifkan..."
    while true; do
        STATUS=$(curl -s "http://localhost:3000/api/get-api-key-status?orgId=$ORG_ID")
        if [[ "$STATUS" == "activated" ]]; then
            echo "Kunci API diaktifkan! Melanjutkan..."
            break
        else
            echo "Menunggu kunci API diaktifkan..."
            sleep 5
        fi
    done

    ENV_FILE="$ROOT"/modal-login/.env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # versi macOS
        sed -i '' "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
    else
        # versi Linux
        sed -i "3s/.*/SMART_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
    fi
fi

echo_step "2" "Memeriksa koneksi ke Testnet"
echo -e "\033[38;5;224m"
cat << "EOF"
    ██████  ██            ███████ ██     ██  █████  ██████  ███    ███
    ██   ██ ██            ██      ██     ██ ██   ██ ██   ██ ████  ████
    ██████  ██      █████ ███████ ██  █  ██ ███████ ██████  ██ ████ ██
    ██   ██ ██                 ██ ██ ███ ██ ██   ██ ██   ██ ██  ██  ██
    ██   ██ ███████       ███████  ███ ███  ██   ██ ██   ██ ██      ██

    Dari Gensyn

EOF

# Proses login dan setup
echo_step "2" "Memeriksa koneksi ke Testnet"
# ...existing code for testnet connection...

echo_step "3" "Memilih jenis Swarm"
# ...existing code for swarm selection...

echo_step "4" "Mengatur parameter training"
# ...existing code for parameter selection...

echo_step "5" "Menginstall dependensi yang diperlukan"
echo ">>> Menginstall paket Python yang diperlukan..."
# ...existing code for requirements installation...

echo_step "6" "Konfigurasi Hugging Face"
# ...existing code for HF token setup...

echo_step "7" "Memulai proses training"
echo ">>> Memulai proses training model..."
# ...existing code for training...

wait  # Tetap menjalankan script sampai Ctrl+C
