# Envoy proxy for gRPC-Web
FROM --platform=linux/amd64 envoyproxy/envoy:v1.31-latest

COPY envoy/envoy.yaml /etc/envoy/envoy.yaml

# Envoy listens on 8080 for gRPC-Web
EXPOSE 8080

CMD ["/usr/local/bin/envoy", "-c", "/etc/envoy/envoy.yaml", "-l", "info"]
