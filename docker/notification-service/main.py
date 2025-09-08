from fastapi import FastAPI
from pydantic import BaseModel
import uuid
from datetime import datetime

app = FastAPI(title="Notification API")

notifications_db = {}

class NotificationRequest(BaseModel):
    user_id: str
    message: str
    type: str = "email"

class NotificationResponse(BaseModel):
    id: str
    user_id: str
    message: str
    type: str
    created_at: str
    status: str

@app.get("/health")
def health():
    return {"status": "healthy", "service": "notification-api"}

@app.post("/notify", response_model=NotificationResponse)
def send_notification(notification: NotificationRequest):
    notif_id = str(uuid.uuid4())[:8]
    notif_data = NotificationResponse(
        id=notif_id,
        user_id=notification.user_id,
        message=notification.message,
        type=notification.type,
        created_at=datetime.now().isoformat(),
        status="sent"
    )
    notifications_db[notif_id] = notif_data
    return notif_data

@app.get("/notifications/{user_id}")
def get_notifications(user_id: str):
    user_notifications = [n for n in notifications_db.values() if n.user_id == user_id]
    return {"user_id": user_id, "notifications": user_notifications}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8081)