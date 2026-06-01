from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.database import engine, Base
from app.config import settings
from app.routers import auth, users, vehicles, incidents, workshops, payments, admin, rental_vehicles, audit_logs, technicians, offers, technician_portal, ai_analysis, notifications, reports
from pathlib import Path

# Create database tables
Base.metadata.create_all(bind=engine)


def _run_startup_migrations() -> None:
    migration_files = [
        Path(__file__).parent / "migrations" / "2026_04_24_marketplace_offers.sql",
        Path(__file__).parent / "migrations" / "2026_04_24_technician_portal.sql",
        Path(__file__).parent / "migrations" / "2026_04_27_notifications_and_paymentmethod.sql",
        Path(__file__).parent / "migrations" / "2026_05_28_stripe_payments.sql",
        Path(__file__).parent / "migrations" / "2026_05_29_cu22_offline_sync.sql",
    ]

    for migration_file in migration_files:
        if not migration_file.exists():
            continue

        sql_script = migration_file.read_text(encoding="utf-8").strip()
        if not sql_script:
            continue

        with engine.begin() as connection:
            raw_connection = connection.connection
            with raw_connection.cursor() as cursor:
                cursor.execute(sql_script)


_run_startup_migrations()

app = FastAPI(
    title="AutoGo API",
    description="API para plataforma de emergencias vehiculares con Mapbox, talleres y pagos",
    version="2.0.0",
    redirect_slashes=False
)

default_origins = [
    "http://localhost",
    "http://localhost:4200",
    "http://127.0.0.1:4200",
    "https://autogo-frontend-150869484553.us-central1.run.app",
    "https://autogo-frontend-g4ctv55smq-uc.a.run.app",
]

cors_origins = [
    origin.strip()
    for origin in (getattr(settings, "BACKEND_CORS_ORIGINS", "") or "").split(",")
    if origin.strip()
]

if not cors_origins:
    cors_origins = default_origins

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(vehicles.router)
app.include_router(incidents.router)
app.include_router(offers.router)
app.include_router(workshops.router)
app.include_router(technicians.router)
app.include_router(technician_portal.router)
app.include_router(payments.router)
app.include_router(admin.router)
app.include_router(rental_vehicles.router)
app.include_router(audit_logs.router)
app.include_router(ai_analysis.router)
app.include_router(notifications.router)
app.include_router(reports.router)


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
