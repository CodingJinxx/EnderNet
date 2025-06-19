# EnderNet
Hosting Solution for Minecraft Modpacks that backs worlds up to a git repo in intervals and checks for new worlds.

This allows a group of friends to play on the same world with one person at a time hosting the world. If someone else than the original hoster wants to host it will automatically pull the latest backup from a git repo.

Also includes a ddns that can be configured to your liking

# How to Setup

## Prerequisites
WSL2
Docker

## Networking 
Your Router must forward incoming connections from outside of your LAN to your PC that is running these containers.

For this you want to create Port Forward Rule on your Routers Homepage for the port 25565 to your local PC IP using TCP/UDP

You will also need to open those ports on your local pcs Firewall for both TCP/UDP

Then you will also need to proxy your WSL2 virtual lan to the your Local Network, again the same ports.

For this there is a script named Bridge_WslPorts.ps1, this must be run as admin.

## Backup Config
Run `docker-compose up backup-service` once, this will populate a ssh key in ./ssh
You must add this id_rsa.pub to a repo deploy keys, for the backup-service to be able to push/pull worlds.

## Running
Once all of the above is done, you can start it with `docker-compose up --build`


# DDNS Settings

Config Template:

```
{
    "settings": [
      {
        "provider": "vultr",
        "domain": "minecraft.jinxx.eu",
        "apikey": "",
        "ttl": 300,
        "ip_version": "ipv4"
      }
    ]
  }
```

# WSL Port Forwarding

Run Bridge_WslPorts.ps1 to expose 25565 to your local network.

Schedule_WslPorts_Task.ps1 Creates a task in order for this to happen at login

# Running the container

First Time run: docker-compose up --build