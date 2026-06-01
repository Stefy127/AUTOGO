from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    ENVIRONMENT: str = "development"
    BACKEND_CORS_ORIGINS: Optional[str] = None
    
    # CICLO 2 - Mapbox Integration
    MAPBOX_API_KEY: Optional[str] = None
    
    # CICLO 2 - AI Features
    AI_ENABLED: bool = False
    GEMINI_API_KEY: Optional[str] = None
    
    # CICLO 2 - Workshop Assignment
    MAX_WORKSHOP_DISTANCE_KM: float = 50.0

    # CU25 - Stripe (fase 1 preparación)
    STRIPE_SECRET_KEY: str = ""
    STRIPE_WEBHOOK_SECRET: str = ""
    STRIPE_SUCCESS_URL: str = "http://localhost:4200/#/payment-success"
    STRIPE_CANCEL_URL: str = "http://localhost:4200/#/payment-cancel"
    STRIPE_CURRENCY: str = "usd"

    class Config:
        env_file = ".env"


settings = Settings()
