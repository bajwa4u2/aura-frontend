# ---------- Build stage ----------
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# Cache bust: change this value to force rebuild when needed
ARG CACHEBUST=1
RUN echo "[build] CACHEBUST=$CACHEBUST" && date

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Another cache bust right before compilation (makes it obvious in logs)
RUN echo "[build] compiling..." && date
RUN flutter build web --release --pwa-strategy=none

# ---------- Runtime stage ----------
FROM nginx:alpine

COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080

CMD ["/bin/sh", "-c", "export PORT=${PORT:-8080}; echo \"[boot] PORT=$PORT\"; envsubst '$PORT' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf; echo \"[boot] Rendered nginx conf:\"; cat /etc/nginx/conf.d/default.conf; nginx -g 'daemon off;'"]
