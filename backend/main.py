from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import engine, Base
from app.routers import auth, users, vehicles, incidents, workshops, payments, admin

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="AutoGo API",
    description="API para plataforma de emergencias vehiculares con Mapbox, talleres y pagos",
    version="2.0.0"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(vehicles.router)
app.include_router(incidents.router)
app.include_router(workshops.router)
app.include_router(payments.router)
app.include_router(admin.router)


@app.get("/")
def read_root():
    return {
        "message": "Welcome to AutoGo API - CICLO 2",
        "version": "2.0.0",
        "status": "running",
        "features": [
            "Authentication & Authorization",
            "Vehicle Management",
            "Incident Management with AI",
            "Workshop Management",
            "Payment System",
            "Mapbox Integration",
            "Admin Dashboard"
        ]
    }


@app.get("/health")
def health_check():
    return {"status": "healthy", "version": "2.0.0"}
