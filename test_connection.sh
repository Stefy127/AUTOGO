#!/bin/bash

echo "🔍 Diagnóstico de Conexión Flutter → Backend"
echo "=============================================="
echo ""

# Obtener IP local
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "✅ IP Local: $LOCAL_IP"
echo ""

# Verificar backend
echo "🔧 Verificando Backend..."
if curl -s http://localhost:8000/docs > /dev/null; then
    echo "✅ Backend respondiendo en localhost:8000"
else
    echo "❌ Backend NO responde en localhost:8000"
fi
echo ""

# Verificar puerto escuchando
echo "🔌 Puertos escuchando..."
netstat -tuln 2>/dev/null | grep :8000 || ss -tuln | grep :8000
echo ""

# Verificar desde IP local
echo "🌐 Probando desde IP local ($LOCAL_IP)..."
if curl -s http://$LOCAL_IP:8000/docs > /dev/null; then
    echo "✅ Backend accesible desde $LOCAL_IP:8000"
else
    echo "❌ Backend NO accesible desde $LOCAL_IP:8000"
fi
echo ""

# Verificar Docker
echo "🐳 Estado de contenedores Docker..."
docker-compose ps
echo ""

echo "📱 Instrucciones para probar desde el teléfono:"
echo "1. Abre el navegador de tu teléfono"
echo "2. Ve a: http://$LOCAL_IP:8000/docs"
echo "3. Si NO carga, ejecuta: sudo ufw allow 8000"
echo ""
echo "📝 URL configurada en Flutter: http://$LOCAL_IP:8000"
