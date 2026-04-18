from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.database import get_db
from app.models import AuditLog, User, UserRole
from app.schemas import AuditLogCreate, AuditLogResponse

router = APIRouter(prefix="/audit-logs", tags=["audit-logs"])


def _to_response(log: AuditLog) -> AuditLogResponse:
    return AuditLogResponse(
        id=log.id,
        user_id=log.user_id,
        user_email=log.user.email if log.user else None,
        user_full_name=log.user.full_name if log.user else None,
        user_role=log.user.role if log.user else None,
        event_type=log.event_type,
        action=log.action,
        section=log.section,
        endpoint=log.endpoint,
        http_method=log.http_method,
        details=log.details,
        created_at=log.created_at,
    )


@router.post("", response_model=AuditLogResponse, status_code=status.HTTP_201_CREATED)
def create_audit_log(
    payload: AuditLogCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    log = AuditLog(
        user_id=current_user.id,
        event_type=payload.event_type,
        action=payload.action,
        section=payload.section,
        endpoint=payload.endpoint,
        http_method=payload.http_method,
        details=payload.details,
    )
    db.add(log)
    db.commit()
    db.refresh(log)
    return _to_response(log)


@router.get("", response_model=List[AuditLogResponse])
def list_audit_logs(
    skip: int = 0,
    limit: int = 200,
    event_type: Optional[str] = None,
    user_id: Optional[int] = None,
    section: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden acceder a la bitácora",
        )

    query = db.query(AuditLog)

    if event_type:
        query = query.filter(AuditLog.event_type == event_type)

    if user_id:
        query = query.filter(AuditLog.user_id == user_id)

    if section:
        query = query.filter(AuditLog.section.ilike(f"%{section}%"))

    logs = query.order_by(AuditLog.created_at.desc()).offset(skip).limit(limit).all()
    return [_to_response(log) for log in logs]
