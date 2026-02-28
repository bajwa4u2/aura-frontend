# AURA Frontend (Flutter Web) - Public Beta Dockerfile

# Build stage
FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Railway build-time define:
#   API_BASE_URL=https://api.aura.bajwadynesty.us
ARG API_BASE_URL
ENV API_BASE_URL=${API_BASE_URL}

RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# Runtime stage
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx","-g","daemon off;"]
