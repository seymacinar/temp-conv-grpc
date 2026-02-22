# Build stage: Flutter web
# Uses official Flutter image (or build locally and copy build/web)
FROM --platform=linux/amd64 ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app

# Copy pubspec first for layer caching
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

# Runtime: nginx serves static files and proxies gRPC-Web to Envoy
FROM --platform=linux/amd64 nginx:alpine

# Remove default config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy Flutter build from builder
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
