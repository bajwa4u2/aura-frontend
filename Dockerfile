# ---- build stage ----
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Build args from Railway
ARG API_BASE_URL
ARG AURA_ADMIN_USER_IDS

# Default safety (won't break if Railway var missing)
ENV API_BASE_URL=${API_BASE_URL}
ENV AURA_ADMIN_USER_IDS=${AURA_ADMIN_USER_IDS}

# Copy and build
COPY . .

RUN flutter pub get
RUN flutter build web --release \
  --dart-define=API_BASE_URL=${API_BASE_URL} \
  --dart-define=AURA_ADMIN_USER_IDS=${AURA_ADMIN_USER_IDS}

# ---- runtime stage ----
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]