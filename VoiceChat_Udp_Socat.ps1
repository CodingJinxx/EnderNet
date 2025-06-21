$ip = wsl -e ip addr show eth0 | Select-String -Pattern "inet " | ForEach-Object { ($_ -split ' +')[1].Split('/')[0] }

Start-Process -NoNewWindow -FilePath "socat.exe" -ArgumentList "UDP4-RECVFROM:24454,fork,bind=0.0.0.0 UDP4-SENDTO:$ip:24454"
