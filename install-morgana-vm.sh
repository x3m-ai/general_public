#!/bin/bash
set -e
echo "========================================================"
echo "  MORGANA INSTALLATION"
echo "========================================================"

if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Run as root"
    exit 1
fi

echo "[1/8] Updating system..."
apt update && apt upgrade -y

echo "[2/8] Installing Python and Git..."
apt install -y python3 python3-pip python3-venv git curl ca-certificates gnupg

echo "[3/8] Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

echo "[4/8] Cloning Morgana..."
cd /opt
[ -d "Morgana" ] && rm -rf Morgana
git clone --depth 1 --branch morgana-branding https://github.com/x3m-ai/Morgana.git
cd Morgana

echo "[5/8] Installing Python dependencies..."
python3 -m venv venv
source venv/bin/activate
pip install --no-cache-dir -r requirements.txt

echo "[6/8] Building frontend..."
cd plugins/magma
npm install --production
npm run build
npm cache clean --force
cd ../..

echo "[7/8] Creating systemd service..."
cat > /etc/systemd/system/morgana.service <<'EOF'
[Unit]
Description=Morgana - MITRE Caldera Fork
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/Morgana
ExecStart=/opt/Morgana/venv/bin/python server.py --insecure
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable morgana
systemctl start morgana

echo ""
echo "Waiting 30 seconds..."
sleep 30

IP_ADDRESS=$(hostname -I | awk '{print $1}')

echo "[8/8] Creating MOTD..."
cat > /etc/motd <<EOF

╔══════════════════════════════════════════════════════════════╗
║   MORGANA - x3m.ai v1                                        ║
╚══════════════════════════════════════════════════════════════╝

  IP:           $IP_ADDRESS
  Web:          http://$IP_ADDRESS:8888
  Credentials:  admin / admin

  Status:   systemctl status morgana
  Logs:     journalctl -u morgana -f
  Restart:  systemctl restart morgana

EOF

apt autoremove --purge -y
apt clean
rm -rf /var/cache/apt/* /tmp/*

echo ""
echo "✅ INSTALLATION COMPLETE!"
echo ""
echo "  Web: http://$IP_ADDRESS:8888"
echo "  User: admin / admin"
echo ""
