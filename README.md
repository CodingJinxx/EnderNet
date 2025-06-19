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