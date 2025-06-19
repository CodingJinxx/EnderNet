FROM alpine:latest

ENV MODPACK_PATH="/modpacks/modpack.zip"
ENV FORCE_DOWNLOAD=false

RUN apk add --no-cache wget

COPY download.sh /init/download.sh
RUN chmod +x /init/download.sh
