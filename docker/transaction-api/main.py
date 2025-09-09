import os
import uuid
import json
from datetime import datetime
from dotenv import load_dotenv
import httpx

from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, String, Float, DateTime
from sqlalchemy.orm import sessionmaker, Session, declarative_base
import redis

from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response

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

# Constrói a URL do Redis
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = os.getenv("REDIS_PORT", "6379")
REDIS_URL = f"redis://{REDIS_HOST}:{REDIS_PORT}"

NOTIFICATION_SERVICE_URL = os.getenv("NOTIFICATION_SERVICE_URL", "http://notification-service.fintech:8081/webhooks/new-transaction")

# --- Banco de Dados (PostgreSQL) ---
Base = declarative_base()
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

class TransactionDB(Base):
    __tablename__ = "transactions"
    id = Column(String, primary_key=True, index=True)
    amount = Column(Float, nullable=False)
    user_id = Column(String, index=True, nullable=False)
    description = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    status = Column(String, default="completed")

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- Cache (Redis) ---
redis_client = redis.from_url(REDIS_URL)

# --- FastAPI App ---
app = FastAPI(title="Transaction API")

@app.on_event("startup")
def on_startup():
    # Cria a tabela no banco de dados se não existir
    Base.metadata.create_all(bind=engine)

# --- Modelos (Pydantic) ---
class Transaction(BaseModel):
    amount: float
    user_id: str
    description: str

class TransactionResponse(BaseModel):
    id: str
    amount: float
    user_id: str
    description: str
    created_at: datetime
    status: str

    class Config:
        from_attributes = True

# --- Métricas Prometheus ---
transaction_counter = Counter('transactions_total', 'Total transactions created')

# --- Endpoints ---
@app.get("/health")
def health():
    return {"status": "healthy", "service": "transaction-api"}

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.post("/transactions", response_model=TransactionResponse, status_code=201)
async def create_transaction(transaction: Transaction, db: Session = Depends(get_db)):
    tx_id = str(uuid.uuid4())
    tx_data = TransactionDB(
        id=tx_id,
        amount=transaction.amount,
        user_id=transaction.user_id,
        description=transaction.description,
    )
    db.add(tx_data)
    db.commit()
    db.refresh(tx_data)

    transaction_counter.inc()

    # Prepara os dados para o webhook
    tx_response_for_webhook = TransactionResponse.from_orm(tx_data).model_dump()
    tx_response_for_webhook['created_at'] = tx_response_for_webhook['created_at'].isoformat()

    # Enviar webhook para o serviço de notificação
    try:
        async with httpx.AsyncClient() as client:
            await client.post(NOTIFICATION_SERVICE_URL, json=tx_response_for_webhook)
    except httpx.RequestError as e:
        print(f"Falha ao enviar webhook: {e}")

    # Invalida o cache para a busca por ID
    redis_client.delete(f"transaction:{tx_id}")

    return tx_data

@app.get("/transactions/{tx_id}", response_model=TransactionResponse)
def get_transaction(tx_id: str, db: Session = Depends(get_db)):
    # 1. Tenta buscar do cache
    cached_tx = redis_client.get(f"transaction:{tx_id}")
    if cached_tx:
        return TransactionResponse.model_validate_json(cached_tx)

    # 2. Se não está no cache, busca do banco
    db_tx = db.query(TransactionDB).filter(TransactionDB.id == tx_id).first()
    if db_tx is None:
        raise HTTPException(status_code=404, detail="Transaction not found")

    # 3. Salva no cache (com expiração) e retorna
    tx_response = TransactionResponse.from_orm(db_tx)
    redis_client.set(f"transaction:{tx_id}", tx_response.model_dump_json(), ex=3600) # Cache por 1 hora

    return tx_response

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
