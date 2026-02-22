@echo off
REM Generate Go and Dart code from proto files.
REM Run from repo root: scripts\generate.bat

echo Generating Go code...
cd /d "%~dp0..\backend"
protoc -I ../proto --go_out=. --go_opt=module=tempconv/grpc --go-grpc_out=. --go-grpc_opt=module=tempconv/grpc ../proto/tempconv.proto
if errorlevel 1 goto :error

echo Generating Dart code...
cd /d "%~dp0.."
if not exist "frontend\lib\src\generated" mkdir "frontend\lib\src\generated"
set "PATH=%PATH%;%USERPROFILE%\AppData\Local\Pub\Cache\bin"
protoc -I proto --dart_out=grpc:frontend/lib/src/generated proto/tempconv.proto
if errorlevel 1 goto :error

echo Done.
exit /b 0

:error
echo Failed.
exit /b 1
