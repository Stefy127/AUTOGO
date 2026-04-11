#!/bin/bash

# AutoGo Quick Start Script

echo "🚗 AutoGo - Iniciando sistema completo..."
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker no está corriendo"
    echo "Por favor inicia Docker Desktop y ejecuta este script nuevamente"
    exit 1
fi

echo "✅ Docker está corriendo"
echo ""

# Stop any running containers
echo "🛑 Deteniendo contenedores previos..."
docker-compose down 2>/dev/null

echo ""
echo "🔨 Construyendo e iniciando servicios..."
echo "   - PostgreSQL Database"
echo "   - Backend API (FastAPI)"
echo "   - Frontend Web (Angular)"
echo ""

# Build and start
docker-compose up --build -d

echo ""
echo "⏳ Esperando que los servicios estén listos..."
sleep 10

# Check if services are running
if docker ps | grep -q "autogo"; then
    echo ""
    echo "✅ ¡Sistema iniciado correctamente!"
    echo ""
    echo "📍 Servicios disponibles:"
    echo "   - Backend API:  http://localhost:8000"
    echo "   - API Docs:     http://localhost:8000/docs"
    echo "   - Frontend Web: http://localhost"
    echo ""
    echo "📱 Para la app móvil Flutter:"
    echo "   cd movile_front"
    echo "   flutter pub get"
    echo "   flutter run"
    echo ""
    echo "📊 Ver logs:"
    echo "   docker-compose logs -f"
    echo ""
    echo "🛑 Detener servicios:"
    echo "   docker-compose down"
    echo ""
else
    echo ""
    echo "❌ Error al iniciar los servicios"
    echo "Revisa los logs con: docker-compose logs"
    echo ""
fi
