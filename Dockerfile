# ---------- Build Stage ----------
FROM ghcr.io/cirruslabs/flutter:stable AS build

ARG API_BASE_URL=https://api.aura.bajwadynesty.us
ENV API_BASE_URL=${API_BASE_URL}

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

RUN echo "[build] API_BASE_URL=$API_BASE_URL" && \
    flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL


# ---------- Runtime Stage ----------
FROM nginx:alpine

COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html