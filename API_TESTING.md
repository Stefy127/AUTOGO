# Postman Collection para AutoGo API

## Importar en Postman

1. Abre Postman
2. Click en "Import"
3. Copia y pega esta colección

## Endpoints

### 1. Register User
POST http://localhost:8000/auth/register
Content-Type: application/json

```json
{
  "email": "usuario@ejemplo.com",
  "password": "password123",
  "full_name": "Juan Pérez",
  "phone": "1234567890",
  "role": "client"
}
```

### 2. Login
POST http://localhost:8000/auth/login/json
Content-Type: application/json

```json
{
  "email": "usuario@ejemplo.com",
  "password": "password123"
}
```

Respuesta:
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "token_type": "bearer"
}
```

**Importante**: Guarda el `access_token` para usarlo en las siguientes peticiones.

### 3. Get Profile
GET http://localhost:8000/users/profile
Authorization: Bearer {access_token}

### 4. Create Vehicle
POST http://localhost:8000/vehicles
Authorization: Bearer {access_token}
Content-Type: application/json

```json
{
  "brand": "Toyota",
  "model": "Corolla",
  "year": 2020,
  "plate": "ABC123",
  "color": "Blanco"
}
```

### 5. List Vehicles
GET http://localhost:8000/vehicles
Authorization: Bearer {access_token}

### 6. Create Incident
POST http://localhost:8000/incidents
Authorization: Bearer {access_token}
Content-Type: application/json

```json
{
  "vehicle_id": 1,
  "description": "Llanta ponchada en la autopista",
  "latitude": 19.4326,
  "longitude": -99.1332,
  "location_text": "Autopista México-Toluca km 15"
}
```

### 7. List Incidents
GET http://localhost:8000/incidents
Authorization: Bearer {access_token}

### 8. Update Incident Status
PATCH http://localhost:8000/incidents/{incident_id}
Authorization: Bearer {access_token}
Content-Type: application/json

```json
{
  "status": "in_progress"
}
```

Status options: "pending", "in_progress", "resolved", "cancelled"

## Testing Workshop User

Para probar el panel web (taller), crea un usuario con rol "workshop":

```json
{
  "email": "taller@ejemplo.com",
  "password": "password123",
  "full_name": "Taller AutoFix",
  "phone": "5551234567",
  "role": "workshop"
}
```

Luego inicia sesión en http://localhost con estas credenciales.
