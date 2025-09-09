import os
import uuid
from datetime import datetime
from dotenv import load_dotenv

from fastapi import FastAPI, Depends
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, String, DateTime, event
from sqlalchemy.orm import sessionmaker, Session, declarative_base

# Carregar variáveis de ambiente
load_dotenv()

# --- Configuração ---
# Constrói a URL do banco de dados a partir de variáveis de ambiente individuais
DB_USER = os.getenv("DB_USER", "user")
DB_PASSWORD = os.getenv("DB_PASSWORD", "password")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "db")
DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

DB_SCHEMA = "notifications"

# --- Banco de Dados (PostgreSQL) ---
Base = declarative_base()
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Evento para criar o schema se ele não existir
@event.listens_for(engine, 'connect', once=True)
def connect(dbapi_connection, connection_record):
    cursor_obj = dbapi_connection.cursor()
    # Use a sintaxe de parâmetro para o nome do schema para evitar SQL Injection
    cursor_obj.execute("CREATE SCHEMA IF NOT EXISTS %s" % DB_SCHEMA)
    cursor_obj.close()

class NotificationDB(Base):
    __tablename__ = "notifications"
    __table_args__ = {'schema': DB_SCHEMA}

    id = Column(String, primary_key=True, index=True)
    transaction_id = Column(String, index=True)
    user_id = Column(String, index=True, nullable=False)
    message = Column(String)
    status = Column(String, default="pending")
    created_at = Column(DateTime, default=datetime.utcnow)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- FastAPI App ---
app = FastAPI(title="Notification API")

@app.on_event("startup")
def on_startup():
    # Cria a tabela no banco de dados se não existir
    Base.metadata.create_all(bind=engine)

# --- Modelos (Pydantic) ---
class TransactionWebhook(BaseModel):
    id: str
    user_id: str
    description: str
    amount: float
    status: str
    created_at: datetime

class NotificationResponse(BaseModel):
    id: str
    transaction_id: str
    user_id: str
    message: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

# --- Endpoints ---
@app.get("/health")
def health():
    return {"status": "healthy", "service": "notification-api"}

@app.post("/webhooks/new-transaction", status_code=202)
async def receive_new_transaction_webhook(webhook_data: TransactionWebhook, db: Session = Depends(get_db)):
    notif_id = str(uuid.uuid4())
    message = f"Sua transação de R$ {webhook_data.amount:.2f} ({webhook_data.description}) foi {webhook_data.status}."

    notification_data = NotificationDB(
        id=notif_id,
        transaction_id=webhook_data.id,
        user_id=webhook_data.user_id,
        message=message,
        status="created"
    )

    db.add(notification_data)
    db.commit()

    return {"status": "notification created"}

@app.get("/notifications/{user_id}", response_model=list[NotificationResponse])
def get_notifications_by_user(user_id: str, db: Session = Depends(get_db)):
    notifications = db.query(NotificationDB).filter(NotificationDB.user_id == user_id).order_by(NotificationDB.created_at.desc()).all()
    return notifications

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8081)
