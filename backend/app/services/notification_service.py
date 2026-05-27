from app import models


def create_notification(
    db,
    *,
    user_id: int,
    title: str,
    message: str,
    notification_type: str,
    incident_id: int | None = None,
) -> models.Notification:
    notification = models.Notification(
        user_id=user_id,
        incident_id=incident_id,
        title=title,
        message=message,
        notification_type=notification_type,
        is_read=False,
    )
    db.add(notification)
    return notification
