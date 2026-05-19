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
