# ---- Build stage ----
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Default to your live API domain.
# Railway can override this at build time with a build arg if you ever want.
ARG API_BASE_URL=https://api.aura.bajwadynesty.us
ENV API_BASE_URL=${API_BASE_URL}

# Create a non-root user so Flutter doesn't complain.
RUN adduser -D -u 10001 flutteruser

WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./

# Ensure workspace ownership for non-root user
RUN chown -R flutteruser:flutteruser /app

USER flutteruser

RUN flutter pub get

# Copy the rest of the app
COPY . .

RUN echo "[build] API_BASE_URL=$API_BASE_URL" && \
    flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL


# ---- Runtime stage (Nginx) ----
FROM nginx:alpine

COPY nginx.conf /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html