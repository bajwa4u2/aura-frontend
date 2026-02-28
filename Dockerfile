# ---- build stage ----
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

ARG API_BASE_URL
ARG AURA_ADMIN_USER_IDS

ENV API_BASE_URL=${API_BASE_URL}
ENV AURA_ADMIN_USER_IDS=${AURA_ADMIN_USER_IDS}

COPY . .

RUN flutter pub get
RUN flutter build web --release \
  --dart-define=API_BASE_URL=${API_BASE_URL} \
  --dart-define=AURA_ADMIN_USER_IDS=${AURA_ADMIN_USER_IDS}

# ---- runtime stage ----
FROM nginx:alpine

# Copy built web assets
COPY --from=build /app/build/web /usr/share/nginx/html

# Add startup script to write nginx config using $PORT
RUN mkdir -p /docker-entrypoint.d
RUN printf '%s\n' \
'#!/bin/sh' \
'set -e' \
': "${PORT:=8080}"' \
'cat > /etc/nginx/conf.d/default.conf <<EOF' \
'server {' \
'  listen       ${PORT};' \
'  listen  [::]:${PORT};' \
'  server_name  _;' \
'  root   /usr/share/nginx/html;' \
'  index  index.html;' \
'' \
'  location / {' \
'    try_files $uri $uri/ /index.html;' \
'  }' \
'}' \
'EOF' \
> /docker-entrypoint.d/99-port.sh

RUN chmod +x /docker-entrypoint.d/99-port.sh

# (Optional) for clarity
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]