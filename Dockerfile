# Copyright(c) 2021 aasaam software development group
FROM ubuntu:focal

ARG ASM_PUBLIC_APP_TITLE="aasaam distributed media server"
ARG ASM_PUBLIC_APP_NS=adms
ARG HTTP_PROXY
ARG NODE_JS_VERSION=15

LABEL org.label-schema.name="adms" \
  org.label-schema.description="aasaam distributed media server" \
  org.label-schema.url="https://aasaam.com/" \
  org.label-schema.vendor="aasaam" \
  maintainer="Muhammad Hussein Fattahizadeh <m@mhf.ir>"

RUN export DEBIAN_FRONTEND=noninteractive ; \
  export http_proxy=$HTTP_PROXY; \
  export https_proxy=$HTTP_PROXY; \
  export LANG=en_US.utf8 ; \
  export LC_ALL=C.UTF-8 ; \
  apt-get update -y \
  && apt-get -y upgrade && apt-get install -y --no-install-recommends curl wget build-essential ca-certificates ffmpeg file python3 \
    libvips-dev libvips-tools \
  && curl -sL https://deb.nodesource.com/setup_${NODE_JS_VERSION}.x | bash - \
  && apt-get install -y nodejs \
  && echo 'cache = "/tmp/npm"' > /root/.npmrc \
  && npm -g update \
  && npm -g install pm2 \
  && cd /tmp \
  && rm -r /var/lib/apt/lists/* && rm -rf /tmp && mkdir /tmp && chmod 777 /tmp && truncate -s 0 /var/log/*.log

# ADD app /app

# RUN cd /app \
#   && npm install --production

EXPOSE 3000/tcp 3001/tcp

STOPSIGNAL SIGTERM
WORKDIR /app
CMD ["pm2-runtime", "--json", "ecosystem.config.js"]
