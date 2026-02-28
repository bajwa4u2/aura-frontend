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

# Railway sets PORT at runtime; default for local
ENV PORT=8080

# Copy built web assets
COPY --from=build /app/build/web /usr/share/nginx/html

# Use nginx template + envsubst (built into nginx image entrypoint)
RUN rm -f /etc/nginx/conf.d/default.conf \
 && mkdir -p /etc/nginx/templates \
 && printf '%s\n' \
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
> /etc/nginx/templates/default.conf.template

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]