#!/bin/bash

# Read HTTP request
read request_line
while read header && [ "$header" != $'\r' ]; do :; done

# Parse method and path
method=$(echo "$request_line" | cut -d' ' -f1)
path=$(echo "$request_line" | cut -d' ' -f2)

if [[ "$method" == "GET" && "$path" == "/start" ]]; then
  if [ -f /opt/app/start.sh ]; then
    nohup bash /opt/app/start.sh > /opt/app/server.log 2>&1 &
    echo -e "HTTP/1.1 200 OK\r"
    echo -e "\r"
    echo "Server started"
  else
    echo -e "HTTP/1.1 404 Not Found\r"
    echo -e "\r"
    echo "No start.sh found"
  fi

elif [[ "$method" == "GET" && "$path" == "/stop" ]]; then
  PID=$(ps aux | grep '[j]ava' | awk '{print $2}' | head -n1)
  if [ -n "$PID" ]; then
    kill "$PID"
    echo -e "HTTP/1.1 200 OK\r"
    echo -e "\r"
    echo "Server stopped (PID: $PID)"
  else
    echo -e "HTTP/1.1 404 Not Found\r"
    echo -e "\r"
    echo "No Java process found"
  fi

else
  echo -e "HTTP/1.1 400 Bad Request\r"
  echo -e "\r"
  echo "Unknown command"
fi
