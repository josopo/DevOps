# Nextcloud File Server on Raspberry Pi using Docker

This repository contains the configuration files necessary to set up a Nextcloud file server on a Raspberry Pi 4 using Docker. The setup also includes MariaDB for database management and Traefik as a reverse proxy with automatic TLS certificate generation via Cloudflare.

## Project Overview

The goal of this project is to provide a self-hosted, private cloud storage solution using a Raspberry Pi 4 and Docker containers. With an external disk mounted on the Raspberry Pi, you'll have ample space to store photos, documents, and other important files. The setup is designed to be easily replicable, allowing you to create your own cloud storage solution.

### Key Features

- **Nextcloud**: An open-source platform to store, manage, and share files securely.
- **MariaDB**: A relational database to handle Nextcloud’s data management.
- **Traefik**: A reverse proxy and load balancer that manages routing and SSL certificates.
- **Cloudflare**: Used for domain management and securing the connection to the Nextcloud instance.

## Hardware Requirements

- Raspberry Pi 4 (4GB or 8GB recommended)
- SSD (250GB or larger recommended)
- MicroSD card (for Raspberry Pi OS)
- Internet connection

## Setup Guide

1. **Install Raspberry Pi OS**: Download and flash Raspberry Pi OS onto a microSD card.

2. **Update the system and install docker**: Here is a link from the official site how to install docker in your RPI
https://docs.docker.com/engine/install/

3. **Setting Up the SSD**: 
- Connect the SSD to your Raspberry Pi.
- Mount the SSD to /media/nextcloud_storage:
```bash
  sudo mkdir -p /media/nextcloud_storage
  sudo mount /dev/sda1 /media/nextcloud_storage
```
- Edit the fstab file to ensure the SSD mounts automatically
```bash
  sudo nano /etc/fstab
  /dev/sda1 /media/nextcloud_storage ext4 defaults 0 0
```
4. **Configuring Docker Compose**: The docker-compose.yaml file sets up the Nextcloud, MariaDB, and Traefik containers. The SSD is mapped to the /var/www/html/data directory within the Nextcloud container, ensuring that all user data is stored on the SSD.
The traefik.yaml and config.yaml files configures Traefik as a reverse proxy. Traefik is set up to handle TLS certificates automatically using your Cloudflare domain.
 

5. **Running the Containers**: Previosly generate the docker network instead of using the docker default bridge network
```bash
sudo docker network create \
  --driver=bridge \
  --subnet=172.28.5.0/24 \
  --ip-range=172.28.5.128/25 \
  --gateway=172.28.5.1 \
  --opt com.docker.network.bridge.name=brd0 \
  nextcloud_net
```
Navigate to the directory containing your docker-compose.yaml file.
```bash
  sudo docker-compose up -d
```
Access your Nextcloud instance via your domain.

6. **(Optional) Set up your own DNS server**: In case you dont have a DNS server already working in your set up you can use this yaml to run a local pihole container and stablish a DNS record pointing to your RPI.

```yaml
version: "3"

# More info at https://github.com/pi-hole/docker-pi-hole/ and https://docs.pi-hole.net/
services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    ports:
      # DNS Ports
      - "53:53/tcp"
      - "53:53/udp"
      # Default HTTP Port
      - "80:80/tcp"
    environment:
      TZ: '<set your timezone>'
      FTLCONF_webserver_api_password: '<piholepassword>'
    networks:
      - pihole_net
     # Volumes store your data between container upgrades
    volumes:
      - './etc-pihole:/etc/pihole'
      - './etc-dnsmasq.d:/etc/dnsmasq.d'
    #   https://github.com/pi-hole/docker-pi-hole#note-on-capabilities
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 500m

networks:
  pihole_net:
    external: true
```