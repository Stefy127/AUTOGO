@echo off
REM AutoGo Quick Start Script for Windows

echo 🚗 AutoGo - Iniciando sistema completo...
echo.

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Error: Docker no está corriendo
    echo Por favor inicia Docker Desktop y ejecuta este script nuevamente
    pause
    exit /b 1
)

echo ✅ Docker está corriendo
echo.

REM Stop any running containers
echo 🛑 Deteniendo contenedores previos...
docker-compose down 2>nul

echo.
echo 🔨 Construyendo e iniciando servicios...
echo    - PostgreSQL Database
echo    - Backend API (FastAPI)
echo    - Frontend Web (Angular)
echo.

REM Build and start
docker-compose up --build -d

echo.
echo ⏳ Esperando que los servicios estén listos...
timeout /t 10 /nobreak >nul

echo.
echo ✅ ¡Sistema iniciado correctamente!
echo.
echo 📍 Servicios disponibles:
echo    - Backend API:  http://localhost:8000
echo    - API Docs:     http://localhost:8000/docs
echo    - Frontend Web: http://localhost
echo.
echo 📱 Para la app móvil Flutter:
echo    cd movile_front
echo    flutter pub get
echo    flutter run
echo.
echo 📊 Ver logs:
echo    docker-compose logs -f
echo.
echo 🛑 Detener servicios:
echo    docker-compose down
echo.

pause
