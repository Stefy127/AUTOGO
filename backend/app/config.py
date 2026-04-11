from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    DATABASE_URL: str
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    ENVIRONMENT: str = "development"
    
    # CICLO 2 - Mapbox Integration
    MAPBOX_API_KEY: Optional[str] = None
    
    # CICLO 2 - AI Features
    AI_ENABLED: bool = False
    
    # CICLO 2 - Workshop Assignment
    MAX_WORKSHOP_DISTANCE_KM: float = 50.0

    class Config:
        env_file = ".env"


settings = Settings()
