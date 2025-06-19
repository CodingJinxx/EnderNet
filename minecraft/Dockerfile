FROM eclipse-temurin:17

RUN mkdir -p /opt/app /downloads /overrides

WORKDIR /opt/app

RUN apt-get update && apt-get install -y unzip && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]