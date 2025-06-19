FROM eclipse-temurin:17

ENV CONTROL_PORT=8080

RUN mkdir -p /opt/app /downloads /overrides

WORKDIR /opt/app

RUN apt-get update && apt-get install -y unzip socat dos2unix jq && rm -rf /var/lib/apt/lists/*

COPY control.sh /control.sh
COPY entrypoint.sh /entrypoint.sh

RUN dos2unix /entrypoint.sh && chmod +x /entrypoint.sh
RUN dos2unix /control.sh && chmod +x /control.sh

ENTRYPOINT ["/entrypoint.sh"]