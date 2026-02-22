# GKE Deployment Script - Temperature Converter
# Run step-by-step. Set $GCP_PROJECT before running.
# Usage: .\scripts\deploy-gke.ps1 [-Step 1|2|3|4|5|6|7] [-Project "my-gcp-project"]

param(
    [int]$Step = 0,
    [string]$Project = "",
    [string]$Region = "us-central1",
    [string]$Zone = "us-central1-a",
    [string]$ClusterName = "tempconv-cluster"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$RegistryRepo = "tempconv"

function Get-GcpProject {
    if ($Project) { return $Project }
    try {
        $p = (gcloud config get-value project 2>&1) | Out-String
        $p = $p.Trim()
    } catch { $p = "" }
    if (-not $p -or $p -eq "(unset)" -or $p -match "unset") {
        Write-Host "ERROR: GCP project not set." -ForegroundColor Red
        Write-Host "  Run: gcloud config set project YOUR_PROJECT_ID" -ForegroundColor Yellow
        Write-Host "  Or:  .\deploy-gke.ps1 -Project YOUR_PROJECT_ID" -ForegroundColor Yellow
        throw "GCP project required"
    }
    return $p
}

function Test-Prereqs {
    @("gcloud", "kubectl", "docker") | ForEach-Object {
        if (-not (Get-Command $_ -ErrorAction SilentlyContinue)) {
            throw "$_ not found. Install and add to PATH."
        }
    }
    Write-Host "[OK] gcloud, kubectl, docker found" -ForegroundColor Green
}

function Step1-CreateCluster {
    Write-Host "`n=== Step 1: Create GKE Cluster ===" -ForegroundColor Cyan
    $proj = Get-GcpProject
    Write-Host "Project: $proj | Region: $Region | Zone: $Zone"
    
    $clusterExists = $false
    try {
        gcloud container clusters describe $ClusterName --zone $Zone 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $clusterExists = $true }
    } catch {
        # 404 = cluster doesn't exist, expected - will create
    }
    if ($clusterExists) {
        Write-Host "Cluster '$ClusterName' already exists. Skipping creation." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Creating cluster (may take ~5 minutes)..." -ForegroundColor Gray
    gcloud container clusters create $ClusterName `
        --zone $Zone `
        --num-nodes 2 `
        --machine-type e2-small
    
    Write-Host "[OK] Cluster created" -ForegroundColor Green
}

function Step2-ConfigureKubectl {
    Write-Host "`n=== Step 2: Configure kubectl ===" -ForegroundColor Cyan
    gcloud container clusters get-credentials $ClusterName --zone $Zone
    kubectl cluster-info
    Write-Host "[OK] kubectl configured" -ForegroundColor Green
}

function Step3-CreateArtifactRegistry {
    Write-Host "`n=== Step 3: Create Artifact Registry ===" -ForegroundColor Cyan
    $proj = Get-GcpProject
    $registry = "$Region-docker.pkg.dev/$proj/$RegistryRepo"
    
    $repoExists = $false
    try {
        gcloud artifacts repositories describe $RegistryRepo --location=$Region 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $repoExists = $true }
    } catch {
        # NOT_FOUND = repo doesn't exist, will create
    }
    if ($repoExists) {
        Write-Host "Repository '$RegistryRepo' already exists." -ForegroundColor Yellow
    } else {
        gcloud artifacts repositories create $RegistryRepo `
            --repository-format=docker `
            --location=$Region `
            --description="TempConv gRPC images"
    }
    
    Write-Host "Registry: $registry" -ForegroundColor Gray
    Write-Host "[OK] Artifact Registry ready" -ForegroundColor Green
    return $registry
}

function Step4-BuildAndPushImages {
    Write-Host "`n=== Step 4: Build and Push Docker Images ===" -ForegroundColor Cyan
    $proj = Get-GcpProject
    $registry = "$Region-docker.pkg.dev/$proj/$RegistryRepo"
    
    # Configure docker for Artifact Registry
    gcloud auth configure-docker "$Region-docker.pkg.dev" --quiet
    
    Push-Location $RepoRoot
    
    # 1. Backend
    Write-Host "Building backend..." -ForegroundColor Gray
    docker build --platform linux/amd64 -t tempconv-backend:latest ./backend
    docker tag tempconv-backend:latest "$registry/backend:latest"
    docker push "$registry/backend:latest"
    Write-Host "[OK] Backend pushed" -ForegroundColor Green
    
    # 2. Envoy
    Write-Host "Building envoy..." -ForegroundColor Gray
    docker build --platform linux/amd64 -t tempconv-envoy:latest -f envoy/Dockerfile .
    docker tag tempconv-envoy:latest "$registry/envoy:latest"
    docker push "$registry/envoy:latest"
    Write-Host "[OK] Envoy pushed" -ForegroundColor Green
    
    # 3. Frontend (requires flutter build web first)
    Write-Host "Building frontend (ensure 'flutter build web' was run)..." -ForegroundColor Gray
    $webDir = Join-Path $RepoRoot "frontend\build\web"
    if (-not (Test-Path $webDir)) {
        Write-Host "Running flutter build web..." -ForegroundColor Yellow
        Push-Location (Join-Path $RepoRoot "frontend")
        flutter build web
        Pop-Location
    }
    docker build --platform linux/amd64 -t tempconv-frontend:latest -f frontend/Dockerfile.slim ./frontend
    docker tag tempconv-frontend:latest "$registry/frontend:latest"
    docker push "$registry/frontend:latest"
    Write-Host "[OK] Frontend pushed" -ForegroundColor Green
    
    Pop-Location
    Write-Host "[OK] All images pushed to $registry" -ForegroundColor Green
}

function Step5-ApplyManifests {
    Write-Host "`n=== Step 5: Apply Kubernetes Manifests ===" -ForegroundColor Cyan
    $proj = Get-GcpProject
    $registry = "$Region-docker.pkg.dev/$proj/$RegistryRepo"
    $k8sDir = Join-Path $RepoRoot "kubernetes"
    
    # Apply namespace first and wait for propagation
    kubectl apply -f (Join-Path $k8sDir "namespace.yaml")
    Write-Host "Waiting for namespace to be ready..." -ForegroundColor Gray
    Start-Sleep -Seconds 3
    
    # Apply deployments (with registry replacement)
    $tempDir = Join-Path $env:TEMP "tempconv-k8s-$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    Get-ChildItem (Join-Path $k8sDir "*-deployment.yaml") | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        $content = $content -replace 'image: tempconv-backend:latest', "image: $registry/backend:latest"
        $content = $content -replace 'image: tempconv-envoy:latest', "image: $registry/envoy:latest"
        $content = $content -replace 'image: tempconv-frontend:latest', "image: $registry/frontend:latest"
        $content = $content -replace 'imagePullPolicy: IfNotPresent', "imagePullPolicy: Always"
        Set-Content -Path (Join-Path $tempDir $_.Name) -Value $content
    }
    
    kubectl apply -f $tempDir
    Remove-Item -Recurse -Force $tempDir
    
    Write-Host "[OK] Manifests applied" -ForegroundColor Green
}

function Step6-WaitForLoadBalancer {
    Write-Host "`n=== Step 6: Wait for LoadBalancer IP ===" -ForegroundColor Cyan
    Write-Host "Waiting for frontend service to get external IP (may take 1-2 min)..." -ForegroundColor Gray
    
    $maxAttempts = 24
    $attempt = 0
    $ip = $null
    while ($attempt -lt $maxAttempts) {
        try {
            $ip = kubectl get svc -n tempconv frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
        } catch { $ip = $null }
        if ($ip) {
            Write-Host "`n[OK] Frontend is ready!" -ForegroundColor Green
            Write-Host "Open in browser: http://$ip" -ForegroundColor Yellow
            Write-Host "(Use http://127.0.0.1 if localhost has connection issues)" -ForegroundColor Gray
            return $ip
        }
        Start-Sleep -Seconds 5
        $attempt++
        Write-Host "." -NoNewline
    }
    
    Write-Host "`nLoadBalancer IP not ready yet. Check with: kubectl get svc -n tempconv" -ForegroundColor Yellow
}

function Step7-Verify {
    Write-Host "`n=== Step 7: Verify Deployment ===" -ForegroundColor Cyan
    kubectl get pods -n tempconv
    kubectl get svc -n tempconv
    Write-Host "`nPods should be Running. Frontend should have EXTERNAL-IP." -ForegroundColor Gray
}

# Main
Write-Host "TempConv GKE Deployment" -ForegroundColor Magenta
Write-Host "Project: $(Get-GcpProject) | Cluster: $ClusterName | Zone: $Zone`n" -ForegroundColor Gray

Test-Prereqs

switch ($Step) {
    1 { Step1-CreateCluster }
    2 { Step2-ConfigureKubectl }
    3 { Step3-CreateArtifactRegistry }
    4 { Step4-BuildAndPushImages }
    5 { Step5-ApplyManifests }
    6 { Step6-WaitForLoadBalancer }
    7 { Step7-Verify }
    0 {
        Step1-CreateCluster
        Step2-ConfigureKubectl
        Step3-CreateArtifactRegistry | Out-Null
        Step4-BuildAndPushImages
        Step5-ApplyManifests
        Step6-WaitForLoadBalancer
        Step7-Verify
    }
}
