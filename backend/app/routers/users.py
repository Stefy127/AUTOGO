from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app import models, schemas
from app.auth import get_current_active_user

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/profile", response_model=schemas.UserResponse)
def get_profile(
    current_user: models.User = Depends(get_current_active_user)
):
    return current_user


@router.get("/me", response_model=schemas.UserResponse)
def get_current_user_info(
    current_user: models.User = Depends(get_current_active_user)
):
    return current_user
