# Build stage for Go backend
# GKE nodes are amd64; we build for linux/amd64
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Copy go mod files first for layer caching
COPY go.mod go.sum* ./
RUN go mod download

# Copy source (proto and generated code are in backend/)
COPY . .

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /tempconv-server .

# Runtime stage
FROM alpine:3.19

RUN apk --no-cache add ca-certificates

WORKDIR /app
COPY --from=builder /tempconv-server .

EXPOSE 50051

ENTRYPOINT ["./tempconv-server"]
