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

# Railway provides $PORT dynamically (usually 8080)
ENV PORT=8080

# Custom nginx config to listen on $PORT
RUN printf 'server {\n\
  listen       ${PORT};\n\
  listen  [::]:${PORT};\n\
  server_name  _;\n\
  root   /usr/share/nginx/html;\n\
  index  index.html;\n\
\n\
  location / {\n\
    try_files $uri $uri/ /index.html;\n\
  }\n\
}\n' > /etc/nginx/conf.d/default.conf

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]