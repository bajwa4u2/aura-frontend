# ---- build stage ----
# PIN the Flutter SDK. `:stable` is a moving tag — a rebuild silently pulls a
# newer engine than the one developed/tested locally. On 2026-07-01 that drift
# shipped a build whose CanvasKit canvas rendered fully blank (layout ran, DOM
# text-field proxies appeared, zero JS errors) on every device. Keep this tag
# in lockstep with the local `flutter --version` used to verify releases.
FROM ghcr.io/cirruslabs/flutter:3.41.4 AS build

WORKDIR /app

ARG API_BASE_URL
ARG AURA_ADMIN_USER_IDS
ARG AURA_WEB_PUSH_VAPID_PUBLIC_KEY

ENV API_BASE_URL=${API_BASE_URL}
ENV AURA_ADMIN_USER_IDS=${AURA_ADMIN_USER_IDS}

COPY . .

RUN flutter pub get
# Pristine build. A prior deploy shipped STALE build/web even though source
# changed (the compiled main.dart.js kept an old mtime/content) — Docker COPY
# normalises source mtimes, which can defeat Flutter's incremental build cache
# so a changed file is not recompiled. `flutter clean` removes build/ and
# .dart_tool so `flutter build web` always regenerates from the current source.
RUN flutter clean
RUN flutter build web --release --no-wasm-dry-run \
  --dart-define=API_BASE_URL=${API_BASE_URL} \
  --dart-define=AURA_ADMIN_USER_IDS=${AURA_ADMIN_USER_IDS} \
  --dart-define=AURA_WEB_PUSH_VAPID_PUBLIC_KEY=${AURA_WEB_PUSH_VAPID_PUBLIC_KEY}

# Generate per-route index.html variants so crawlers (LinkedInBot,
# Twitterbot, Slackbot, Discordbot) see route-specific OG metadata
# instead of the SPA root fallback. Nginx try_files serves these
# directory indexes before falling back to /index.html.
RUN dart run tool/web/generate_route_metadata.dart

# PRECOMPRESS FOR gzip_static.
#
# The front door was serving main.dart.js at its full 7.2 MB with no
# Content-Encoding at all -- measured in production 2026-08-28 -- so every
# cold load pulled roughly 4-5x more than it needed to.
#
# Compressing at BUILD time rather than per-request buys the maximum ratio
# (-9) once, instead of a middling ratio recomputed on every request, and
# costs the runtime container no CPU. nginx serves the .gz beside the
# original via gzip_static and falls back to on-the-fly gzip for anything
# not precompressed.
#
# -k keeps the original: gzip_static needs BOTH, and a client that sends no
# Accept-Encoding must still get an uncompressed body.
#
# NOT brotli: stock nginx has no brotli module, and nginx:alpine ships no
# ngx_brotli. Claiming brotli here would mean either a custom nginx build or
# a silently-ignored directive. gzip is what this image can actually honour.
RUN find build/web -type f -size +1k \( -name '*.js' -o -name '*.css' -o -name '*.json' -o -name '*.svg' -o -name '*.wasm' -o -name '*.ttf' -o -name '*.otf' \) -exec gzip -9 -k -f {} \;

# ---- runtime stage ----
FROM nginx:alpine

# Railway sets PORT at runtime; default for local
ENV PORT=8080

# Backend origin that owns /p/* (dynamic share pages). Crawlers fetch
# auraplatform.org/p/<id>; nginx proxies the request to the NestJS
# share controller which renders crawler-visible OG HTML. Override by
# setting AURA_BACKEND_API_ORIGIN at deploy time.
ENV AURA_BACKEND_API_ORIGIN=https://api.auraplatform.org

# Copy built web assets
COPY --from=build /app/build/web /usr/share/nginx/html

# Use nginx template + envsubst (built into nginx image entrypoint).
# envsubst replaces ${PORT} and ${AURA_BACKEND_API_ORIGIN} from the
# environment; nginx's own variables ($uri, $host, $remote_addr,
# $proxy_add_x_forwarded_for, $scheme) are left intact because no
# env var of those names exists.
RUN rm -f /etc/nginx/conf.d/default.conf \
 && mkdir -p /etc/nginx/templates \
 && printf '%s\n' \
'# Canonical application origin. auraplatform.org is the ONE canonical' \
'# browser origin. app.auraplatform.org stays reachable as a legacy entry' \
'# point but is not a second supported origin: two equal origins mean two' \
'# different same-origin sets, and the governed media door can only be' \
'# same-origin for one of them. Path and query are preserved so bookmarks' \
'# and Stripe billing returns (/billing/success, /billing/cancel) survive.' \
'server {' \
'  listen       ${PORT};' \
'  listen  [::]:${PORT};' \
'  server_name  app.auraplatform.org www.auraplatform.org;' \
'  return 301 https://auraplatform.org$request_uri;' \
'}' \
'' \
'server {' \
'  listen       ${PORT} default_server;' \
'  listen  [::]:${PORT} default_server;' \
'  server_name  _;' \
'  root   /usr/share/nginx/html;' \
'  index  index.html;' \
'' \
'  # ── Redirect-leak guard ─────────────────────────────────────────' \
'  # Railway terminates TLS at its edge; this nginx upstream sees plain' \
'  # HTTP on ${PORT}. Without these two directives, any nginx-issued' \
'  # redirect (e.g. the implicit trailing-slash redirect for directory' \
'  # access) is rendered as an ABSOLUTE URL built from the upstream' \
'  # scheme + Host + listen port, producing `Location: http://host:8080/...`' \
'  # — which is exactly what Microsoft Store certification rejected on' \
'  # https://auraplatform.org/privacy. With both off, nginx emits' \
'  # relative redirects (just `Location: /privacy/`) and the Railway' \
'  # edge serves them under the original https://host.' \
'  absolute_redirect off;' \
'  port_in_redirect off;' \
'  server_tokens off;' \
'' \
'  # ── Compression ─────────────────────────────────────────────────' \
'  # The bundle was served UNCOMPRESSED: 7.2 MB of main.dart.js with no' \
'  # Content-Encoding, revalidated on every visit. gzip_static serves the' \
'  # .gz produced at build time (max ratio, zero runtime CPU); gzip covers' \
'  # anything without a precompressed twin, such as proxied share pages.' \
'  gzip_static on;' \
'  gzip on;' \
'  gzip_comp_level 6;' \
'  gzip_min_length 1024;' \
'  gzip_proxied any;' \
'  # Vary: Accept-Encoding — without it a shared cache can hand a' \
'  # compressed body to a client that never asked for one.' \
'  gzip_vary on;' \
'  # text/html is always compressed when gzip is on and must not be listed.' \
'  gzip_types text/plain text/css application/javascript application/json' \
'             application/manifest+json image/svg+xml application/wasm' \
'             font/ttf font/otf;' \
'' \
'  # App shell / entrypoints have STABLE names but change every build, so' \
'  # they MUST revalidate. Serving them immutable (below) froze returning' \
'  # users on the old build for up to 30 days — the root cause of the' \
'  # "stale frontend after deploy" problem. no-cache still allows etag 304s.' \
'  # Exact (=) and the .part.js regex are matched before the immutable rule.' \
'  location = /index.html { add_header Cache-Control "no-cache"; }' \
'  location = /flutter_service_worker.js { add_header Cache-Control "no-cache"; }' \
'  location = /flutter_bootstrap.js { add_header Cache-Control "no-cache"; }' \
'  location = /version.json { add_header Cache-Control "no-cache"; }' \
'  location = /main.dart.js { add_header Cache-Control "no-cache"; }' \
'  location ~* \.part\.js$ { try_files $uri =404; add_header Cache-Control "no-cache"; }' \
'' \
'  # Cache truly content-addressed assets aggressively (hashed names).' \
'  location ~* \.(?:js|css|png|jpg|jpeg|gif|svg|webp|ico|woff2?)$ {' \
'    try_files $uri =404;' \
'    expires 30d;' \
'    add_header Cache-Control "public, max-age=2592000, immutable";' \
'  }' \
'' \
'  # Dynamic share pages. Proxied to the NestJS share controller so' \
'  # LinkedInBot / Twitterbot / Slackbot / Discordbot / facebookexternalhit' \
'  # receive route-specific OG metadata for posts, institution posts,' \
'  # and announcements. Human visitors are bounced into the workspace' \
'  # SPA by the backend response (meta-refresh + JS redirect).' \
'  location /p/ {' \
'    resolver 1.1.1.1 8.8.8.8 valid=300s ipv6=off;' \
'    resolver_timeout 5s;' \
'    proxy_pass ${AURA_BACKEND_API_ORIGIN}/v1/p/;' \
'    proxy_http_version 1.1;' \
'    proxy_ssl_server_name on;' \
'    proxy_set_header Host api.auraplatform.org;' \
'    proxy_set_header X-Forwarded-Host $host;' \
'    proxy_set_header X-Forwarded-Proto $scheme;' \
'    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' \
'    proxy_set_header X-Real-IP $remote_addr;' \
'    proxy_read_timeout 15s;' \
'    proxy_connect_timeout 5s;' \
'  }' \
'' \
'  # Governed media door (same-origin first hop). THIS BLOCK EXISTS FOR' \
'  # ONE REASON: browser CORS. The API returns a 302 to a signed private' \
'  # R2 URL. Reached CROSS-origin, the Fetch spec replaces the request' \
'  # origin with an opaque one before following that redirect, so R2 sees' \
'  # Origin: null, matches no rule in a correct policy, and the browser' \
'  # discards a 200 it already holds. Every avatar, cover and institution' \
'  # logo vanished that way, seen as statusCode 0 from image resource' \
'  # service. Serving the SAME path on the app origin makes the first hop' \
'  # same-origin, so the real Origin survives and the EXISTING R2 policy' \
'  # matches. No bucket change, no Origin:null.' \
'  #' \
'  # nginx is TRANSPORT ONLY here. It decides nothing about visibility,' \
'  # quarantine, readiness or parent access; it forwards to the canonical' \
'  # API route, which stays the single Media authority. Authorization and' \
'  # Cookie headers pass through unchanged, so an anonymous request stays' \
'  # anonymous and a bearer request keeps its elevation.' \
'  #' \
'  # proxy_redirect off is load-bearing: the 302 must reach the BROWSER' \
'  # untouched so the BROWSER follows it to R2. Following or rewriting it' \
'  # here would put media bytes back on Railway.' \
'  # PUBLIC OG DOOR (same-origin, STABLE BYTES).' \
'  #' \
'  # Unlike /raw below, no redirect passes through here. og:image used to' \
'  # resolve to /raw, which answers 302 to a presigned storage URL that' \
'  # expires in ten minutes. LinkedIn fetches inside that window and' \
'  # hydrates; Facebook re-fetches on cache refresh and lost the race. This' \
'  # door streams bytes from an address that never expires.' \
'  #' \
'  # nginx is TRANSPORT ONLY here too: the API re-decides visibility on' \
'  # every request with the identity that arrives, so an anonymous caller' \
'  # with no entitlement is refused there, not here.' \
'  location ~ ^/media/[^/]+/public$ {' \
'    resolver 1.1.1.1 8.8.8.8 valid=300s ipv6=off;' \
'    resolver_timeout 5s;' \
'    proxy_pass ${AURA_BACKEND_API_ORIGIN}/v1$request_uri;' \
'    proxy_http_version 1.1;' \
'    proxy_ssl_server_name on;' \
'    proxy_set_header Host api.auraplatform.org;' \
'    proxy_set_header X-Forwarded-Host $host;' \
'    proxy_set_header X-Forwarded-Proto $scheme;' \
'    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' \
'    proxy_set_header X-Real-IP $remote_addr;' \
'    proxy_read_timeout 30s;' \
'    proxy_connect_timeout 5s;' \
'    proxy_buffering off;' \
'  }' \
'' \
'  # A real robots policy, never the SPA fallback. A crawler asking for a' \
'  # policy used to receive index.html, which is not a policy -- it is an' \
'  # HTML page a parser has to guess about. Permissive for exactly what' \
'  # external previews need, closed for the application surface.' \
'  location = /robots.txt {' \
'    default_type text/plain;' \
'    return 200 "User-agent: *\nAllow: /p/\nAllow: /media/\nAllow: /institutions\nAllow: /u/\nDisallow: /admin\nDisallow: /institution/\nDisallow: /messages\nDisallow: /conversations\nDisallow: /activity\nDisallow: /notifications\nDisallow: /saved\nDisallow: /settings\nDisallow: /me\n";' \
'  }' \
'' \
'  location ~ ^/media/[^/]+/raw$ {' \
'    resolver 1.1.1.1 8.8.8.8 valid=300s ipv6=off;' \
'    resolver_timeout 5s;' \
'    proxy_pass ${AURA_BACKEND_API_ORIGIN}/v1$request_uri;' \
'    proxy_http_version 1.1;' \
'    proxy_ssl_server_name on;' \
'    proxy_set_header Host api.auraplatform.org;' \
'    proxy_set_header X-Forwarded-Host $host;' \
'    proxy_set_header X-Forwarded-Proto $scheme;' \
'    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' \
'    proxy_set_header X-Real-IP $remote_addr;' \
'    proxy_redirect off;' \
'    proxy_read_timeout 30s;' \
'    proxy_connect_timeout 5s;' \
'  }' \
'' \
'  # Flutter SPA fallback. The `$uri/index.html` clause lets a request' \
'  # for /privacy resolve directly to /privacy/index.html (a per-route' \
'  # variant produced by tool/web/generate_route_metadata.dart) WITHOUT' \
'  # the implicit trailing-slash 301 redirect that previously bounced' \
'  # Microsoft cert bots into a broken http://host:8080/privacy/ URL.' \
'  # Order matters: file → directory-index file → directory → SPA root.' \
'  location / {' \
'    try_files $uri $uri/index.html $uri/ /index.html;' \
'  }' \
'}' \
> /etc/nginx/templates/default.conf.template

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]