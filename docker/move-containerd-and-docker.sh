# stop all containers
docker ps -q | xargs -r docker stop

# stop services
sudo systemctl stop docker
sudo systemctl stop containerd

# Copy data
sudo mkdir -p /opt/data/containerd
sudo chown root:root /opt/data/containerd
sudo chmod 711 /opt/data/containerd

sudo rsync -aHAXP /var/lib/containerd/ /opt/data/containerd/

# configure container d
sudo mkdir -p /etc/containerd
if [ ! -f /etc/containerd/config.toml ]; then
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
fi

sudo mv /etc/containerd/config.toml /etc/containerd/config.tomlold
sudo containerd config default > ~/etc/containerd/config.toml

#EDIT
sudo nano /etc/containerd/config.toml

# at the top you'll see root = '/var/lib/containerd' change it to:  root = '/opt/data/containerd'

# safety bnckup
sudo mv /var/lib/containerd /var/lib/containerd.old

# restart services
sudo systemctl daemon-reexec
sudo systemctl start containerd
sudo systemctl start docker

# verify
sudo ctr version || true
docker info | grep "Docker Root Dir" || true
sudo du -sh /opt/data/containerd || true
sudo du -sh /var/lib/containerd.old || true

### docker

# stop all containers
docker ps -q | xargs -r docker stop

# stop services
sudo systemctl stop docker
sudo systemctl stop containerd

# Copy data
sudo mkdir -p /opt/data/docker
sudo rsync -aHAXP /var/lib/docker/ /opt/data/docker/
#!!! IMPORTANT (no trailing slash mistakes — this one is correct)

# configure docker
sudo nano /etc/docker/daemon.json

# Put:
{
  "data-root": "/opt/data/docker",
  "builder": {
    "gc": {
      "enabled": true,
      "defaultKeepStorage": "5GB"
    }
  }
}


# safety backup
sudo mv /var/lib/docker /var/lib/docker.old

# restart services
sudo systemctl start containerd
sudo systemctl start docker

# verify
docker info | grep "Docker Root Dir"

# test
docker run hello-world

# reclaim old space, delte safety backup WHEN HAPPY
sudo rm -rf /var/lib/docker.old
