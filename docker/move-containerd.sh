# ---------------------------

# STEP 1 — Stop docker stack

# ---------------------------

echo "Stopping containers and services..."
docker ps -q | xargs -r docker stop
sudo systemctl stop docker
sudo systemctl stop containerd

# ---------------------------

# STEP 2 — Create new storage location

# ---------------------------

echo "Creating new containerd directory..."
sudo mkdir -p /opt/data/containerd
sudo chown root:root /opt/data/containerd
sudo chmod 711 /opt/data/containerd

# ---------------------------

# STEP 3 — Copy existing data (can take a minute)

# ---------------------------

echo "Copying containerd data..."
sudo rsync -aHAXP /var/lib/containerd/ /opt/data/containerd/

# ---------------------------

# STEP 4 — Create default config (if missing)

# ---------------------------

echo "Creating containerd config if not present..."
sudo mkdir -p /etc/containerd
if [ ! -f /etc/containerd/config.toml ]; then
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
fi

# ---------------------------

# STEP 5 — Modify root path

# ---------------------------

echo "Updating containerd root path..."
##sudo sed -i 's|root = "/var/lib/containerd"|root = "/opt/data/containerd"|' /etc/containerd/config.toml
sudo mv /etc/containerd/config.toml /etc/containerd/config.tomlold
sudo containerd config default > ~/etc/containerd/config.toml

#EDIT
sudo nano /etc/containerd/config.toml

#at the top you'll see root = '/var/lib/containerd' change it to:  root = '/opt/data/containerd'

# ---------------------------

# STEP 6 — Safety rollback backup

# ---------------------------

echo "Renaming old directory for rollback safety..."
sudo mv /var/lib/containerd /var/lib/containerd.old

# ---------------------------

# STEP 7 — Restart services

# ---------------------------

echo "Starting services..."
sudo systemctl daemon-reexec
sudo systemctl start containerd
sudo systemctl start docker

# ---------------------------

# STEP 8 — Verify

# ---------------------------

echo "Verifying new location..."
sudo ctr version || true
docker info | grep "Docker Root Dir" || true
echo "Containerd disk usage:"
sudo du -sh /opt/data/containerd || true
echo "Old directory (should not be used anymore):"
sudo du -sh /var/lib/containerd.old || true

# ============================================================

# STEP 9 — FINAL CLEANUP (RUN ONLY AFTER SUCCESSFUL BUILDS)

# Uncomment when confident everything works

# ============================================================

# echo "Removing old containerd data..."

# sudo rm -rf /var/lib/containerd.old
