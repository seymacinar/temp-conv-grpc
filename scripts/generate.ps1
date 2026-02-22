# Generate Go and Dart code from proto files.
# Run from repo root: .\scripts\generate.ps1

$ErrorActionPreference = "Stop"
$ProtoDir = Join-Path $PSScriptRoot "..\proto"
$BackendDir = Join-Path $PSScriptRoot "..\backend"
$FrontendDir = Join-Path $PSScriptRoot "..\frontend"

Write-Host "Generating Go code..."
Set-Location $BackendDir
$ProtoFile = Join-Path $ProtoDir "tempconv.proto"
protoc -I $ProtoDir --go_out=. --go_opt=module=tempconv/grpc `
    --go-grpc_out=. --go-grpc_opt=module=tempconv/grpc $ProtoFile

Write-Host "Generating Dart code..."
$FrontendGenerated = Join-Path $FrontendDir "lib\src\generated"
if (-not (Test-Path $FrontendGenerated)) { New-Item -ItemType Directory -Path $FrontendGenerated -Force }
protoc -I $ProtoDir --dart_out=grpc:$FrontendGenerated $ProtoFile

Write-Host "Done."
