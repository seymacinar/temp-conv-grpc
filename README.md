# Temperature Converter – gRPC Distributed Application

A simple distributed application for temperature conversion (Celsius ↔ Fahrenheit) built with **Go gRPC**, **Flutter Web**, **Envoy** (gRPC-Web proxy), **Docker**, and **Kubernetes (GKE)**.

## Architecture

```
┌─────────────────┐     gRPC-Web      ┌─────────────┐     gRPC      ┌─────────────┐
│  Flutter Web    │ ────────────────► │   Envoy     │ ────────────► │  Go Backend │
│  (nginx)        │                   │   Proxy     │               │  (gRPC)     │
└─────────────────┘                   └─────────────┘               └─────────────┘
       :80                                   :8080                        :50051
```

- **Frontend**: Flutter web app served by nginx. Uses gRPC-Web to talk to the backend (no REST/JSON).
- **Envoy**: Translates gRPC-Web (HTTP/1.1) from the browser to gRPC (HTTP/2) for the backend.
- **Backend**: Go gRPC server with two RPCs: `CelsiusToFahrenheit` and `FahrenheitToCelsius`.

---

## Step-by-Step Guide

### Step 1: Protocol Buffers Definition

The service is defined in `proto/tempconv.proto`:

```protobuf
service TemperatureConverter {
  rpc CelsiusToFahrenheit(CelsiusRequest) returns (FahrenheitResponse);
  rpc FahrenheitToCelsius(FahrenheitRequest) returns (CelsiusResponse);
}
```

**Why**: A single `.proto` file defines the API and is the source of truth for both Go and Dart code. No REST, no manual JSON handling.

### Step 2: Generate Code

**Go** (requires `protoc`, `protoc-gen-go`, `protoc-gen-go-grpc`):

```powershell
cd backend
protoc -I ../proto --go_out=. --go_opt=module=tempconv/grpc --go-grpc_out=. --go-grpc_opt=module=tempconv/grpc ../proto/tempconv.proto
```

**Dart** (requires `protoc`, `protoc-gen-dart` via `dart pub global activate protoc_plugin`):

```powershell
protoc -I proto --dart_out=grpc:frontend/lib/src/generated proto/tempconv.proto
```

Or use the script:

```powershell
.\scripts\generate.ps1
```

**Why**: Generated clients and servers ensure type safety and stay in sync with the proto.

### Step 3: Go Backend

- `backend/main.go` – starts the gRPC server on port 50051
- `backend/server/server.go` – implements the conversion RPCs
- `backend/proto/` – generated Go code

Run locally:

```powershell
cd backend
go run .
```

Test:

```powershell
go test ./...
```

### Step 4: Flutter Web Frontend

- Uses `GrpcWebClientChannel` to talk to the backend via gRPC-Web
- Connects to the same origin (Envoy is behind the same host)

Build:

```powershell
cd frontend
flutter pub get
flutter build web
```

Run in dev:

```powershell
flutter run -d chrome
```

**Why gRPC-Web**: Browsers don’t support raw gRPC (HTTP/2). gRPC-Web uses HTTP/1.1 so Envoy can translate it to gRPC.

### Step 5: Envoy Proxy

`envoy/envoy.yaml` configures Envoy to:

- Listen on 8080 for gRPC-Web
- Forward to the `backend` service on port 50051
- Handle the gRPC-Web ↔ gRPC translation

**Why Envoy**: Envoy’s `grpc_web` filter does this translation so the backend stays pure gRPC.

### Step 6: Docker Build

All components are containerized for **linux/amd64** (GKE):

```powershell
# Backend
docker build -t tempconv-backend:latest ./backend

# Envoy
docker build -t tempconv-envoy:latest -f envoy/Dockerfile .

# Frontend (builds Flutter inside Docker – can be slow)
docker build -t tempconv-frontend:latest ./frontend
```

**Alternative**: Build Flutter locally, then use a slim Dockerfile that only copies `build/web` into nginx (faster for iteration).

### Step 7: Local Run with Docker Compose

```powershell
docker compose up --build
```

- Frontend: http://localhost (port 80)
- Backend gRPC: localhost:50051 (for direct access)

### Step 8: Deploy to GKE

**Prerequisites:** `gcloud` configured, `gcloud auth login` done, project set (`gcloud config set project YOUR_PROJECT`).

**All-in-one deploy:**

```powershell
.\scripts\deploy-gke.ps1
```

**Step-by-step (run each step separately):**

```powershell
# Step 1: Create cluster (~5 min)
.\scripts\deploy-gke.ps1 -Step 1

# Step 2: Configure kubectl
.\scripts\deploy-gke.ps1 -Step 2

# Step 3: Create Artifact Registry
.\scripts\deploy-gke.ps1 -Step 3

# Step 4: Build & push images (~5–10 min)
.\scripts\deploy-gke.ps1 -Step 4

# Step 5: Apply Kubernetes manifests
.\scripts\deploy-gke.ps1 -Step 5

# Step 6: Wait for LoadBalancer IP
.\scripts\deploy-gke.ps1 -Step 6

# Step 7: Verify
.\scripts\deploy-gke.ps1 -Step 7
```

**Options:** `-Project "my-project"` `-Region "europe-west1"` `-Zone "europe-west1-b"` `-ClusterName "my-cluster"`

Open the reported LoadBalancer IP in a browser (e.g. `http://34.x.x.x`). Use `http://127.0.0.1` if `localhost` causes connection issues.

### Step 9: Load Testing with k6

The load test uses k6’s native gRPC client to call the backend (same logic as when using gRPC-Web through Envoy).

1. Expose the backend (or port-forward):

```powershell
kubectl port-forward -n tempconv svc/backend 50051:50051
```

2. Run the load test:

```powershell
k6 run loadtest/k6-grpc-web.js
```

Or with a custom backend URL:

```powershell
k6 run -e BACKEND_URL=127.0.0.1:50051 loadtest/k6-grpc-web.js
```

**Why k6**: Simulates many concurrent clients and checks latency and error rate to verify performance and stability.

---

## Project Structure

```
TempConv-grpc/
├── proto/
│   └── tempconv.proto
├── backend/
│   ├── main.go
│   ├── server/
│   ├── proto/           # generated Go code
│   ├── Dockerfile
│   └── go.mod
├── frontend/
│   ├── lib/
│   │   ├── main.dart
│   │   └── src/
│   │       ├── generated/   # generated Dart code
│   │       ├── grpc_client*.dart
│   │       └── screens/
│   ├── nginx.conf
│   ├── Dockerfile
│   └── pubspec.yaml
├── envoy/
│   ├── envoy.yaml
│   └── Dockerfile
├── kubernetes/
│   ├── namespace.yaml
│   ├── backend-deployment.yaml
│   ├── envoy-deployment.yaml
│   └── frontend-deployment.yaml
├── loadtest/
│   ├── k6-grpc-web.js
│   └── proto/
├── scripts/
│   └── generate.ps1
├── docker-compose.yaml
└── README.md
```

---

## Prerequisites

- Go 1.21+
- Flutter (for web)
- Docker
- kubectl
- Google Cloud SDK & `gke-gcloud-auth-plugin`
- k6
- protoc and plugins (protoc-gen-go, protoc-gen-go-grpc, protoc-gen-dart)
