# ---- Build stage ----
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy only pubspec first for better caching
COPY pubspec.yaml ./

# Generate deps (pubspec.lock will be created inside the container)
RUN flutter pub get

# Now copy the rest of the project
COPY . .

# Build web with API base
ARG API_BASE_URL=https://api.aura.bajwadynesty.us
RUN echo "[build] API_BASE_URL=${API_BASE_URL}" && \
    flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# ---- Runtime stage ----
FROM nginx:alpine

# If you have nginx.conf in repo, keep this. If not, tell me.
COPY nginx.conf /etc/nginx/templates/default.conf.template

COPY --from=build /app/build/web /usr/share/nginx/html