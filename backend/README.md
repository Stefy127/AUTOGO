# AutoGo Backend API

API REST para plataforma de emergencias vehiculares.

## Tecnologías

- FastAPI
- SQLAlchemy
- PostgreSQL
- JWT Authentication
- Pydantic

## Instalación

```bash
pip install -r requirements.txt
```

## Ejecutar

```bash
uvicorn main:app --reload
```

## Documentación

http://localhost:8000/docs

## Variables de Entorno

Copia `.env.example` a `.env` y ajusta los valores:

```
DATABASE_URL=postgresql://user:pass@localhost:5432/autogo_db
SECRET_KEY=your-secret-key
```

## Estructura

```
backend/
├── app/
│   ├── models.py      # Modelos de base de datos
│   ├── schemas.py     # Esquemas Pydantic
│   ├── auth.py        # Autenticación JWT
│   ├── database.py    # Configuración DB
│   └── routers/       # Endpoints
├── main.py            # Aplicación principal
└── requirements.txt
```
