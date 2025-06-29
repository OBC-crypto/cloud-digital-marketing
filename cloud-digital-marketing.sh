#!/bin/bash

set -e

PROJECT_NAME="cloud-digital-marketing"
CONTAINER_NAME="cloud-digital-marketing"
PORT_WEB=3040
NGROK_LOG="$HOME/${PROJECT_NAME}/ngrok.log"
NGROK_TOKEN=""  # GANTI jika perlu

echo "📁 Membuat direktori proyek..."
mkdir -p ~/${PROJECT_NAME}/config/custom-cont-init.d

echo "🐳 Menyiapkan Docker Compose v2.27.0..."
COMPOSE_VERSION="v2.27.0"
mkdir -p ~/.docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-x86_64 \
  -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
export PATH="$HOME/.docker/cli-plugins:$PATH"
echo "✅ Docker Compose terinstal: $(docker compose version)"

echo "🧾 Membuat docker-compose.yml..."
cat > ~/${PROJECT_NAME}/docker-compose.yml <<EOF
version: '3.9'
services:
  webtop:
    container_name: ${CONTAINER_NAME}
    image: lscr.io/linuxserver/webtop:ubuntu-xfce
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Makassar
      - WEBTOP_PASSWORD=admin123
    volumes:
      - $HOME/${PROJECT_NAME}/config:/config
    ports:
      - "${PORT_WEB}:3000"
    shm_size: "2gb"
    dns:
      - 8.8.8.8
      - 1.1.1.1
    networks:
      - customnet
    restart: unless-stopped

networks:
  customnet:
    driver: bridge
    driver_opts:
      com.docker.network.driver.mtu: 1400
EOF

echo "⚙️ Menambahkan script optimasi jaringan..."
cat > ~/${PROJECT_NAME}/config/custom-cont-init.d/01-boost-network.sh <<'EOF'
#!/bin/bash

echo "⚙️ Optimasi jaringan untuk kecepatan..."

echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p || true

ulimit -n 65535
echo "fs.file-max = 100000" >> /etc/sysctl.conf
sysctl -p || true

echo "✅ Jaringan container telah dioptimasi."
EOF

chmod +x ~/${PROJECT_NAME}/config/custom-cont-init.d/01-boost-network.sh

echo "🚀 Menjalankan container..."
cd ~/${PROJECT_NAME}
docker compose up -d

echo "🌐 Menyiapkan ngrok..."
if ! command -v ngrok >/dev/null; then
  echo "📦 Menginstal ngrok..."
  curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
  echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
  sudo apt update && sudo apt install -y ngrok
fi

ngrok config add-authtoken "${NGROK_TOKEN}"

echo "📡 Menjalankan ngrok tunnel di port ${PORT_WEB}..."
nohup ngrok http ${PORT_WEB} --log=stdout > "${NGROK_LOG}" 2>&1 &
sleep 8

NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -oE 'https://[a-z0-9\-]+\.ngrok-free\.app' | head -n1)

echo "✅ Cloud Digital Marketing Aktif!"
if [[ -n "$NGROK_URL" ]]; then
  echo "🌍 Akses Webtop di: ${NGROK_URL}"
else
  echo "⚠️ Gagal mengambil URL ngrok. Cek log di: ${NGROK_LOG}"
fi
