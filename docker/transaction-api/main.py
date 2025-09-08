from fastapi import FastAPI
from pydantic import BaseModel
import uuid
from datetime import datetime
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response

app = FastAPI(title="Transaction API")

# Métricas Prometheus
transaction_counter = Counter('transactions_total', 'Total transactions created')
health_counter = Counter('health_checks_total', 'Total health checks')

# Simular banco de dados
transactions_db = {}

class Transaction(BaseModel):
    amount: float
    user_id: str
    description: str

class TransactionResponse(BaseModel):
    id: str
    amount: float
    user_id: str
    description: str
    created_at: str
    status: str

@app.get("/health")
def health():
    return {"status": "healthy", "service": "transaction-api"}

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.post("/transactions", response_model=TransactionResponse)
def create_transaction(transaction: Transaction):
    tx_id = str(uuid.uuid4())[:8]
    tx_data = TransactionResponse(
        id=tx_id,
        amount=transaction.amount,
        user_id=transaction.user_id,
        description=transaction.description,
        created_at=datetime.now().isoformat(),
        status="completed"
    )
    transactions_db[tx_id] = tx_data
    return tx_data

@app.get("/transactions/{tx_id}", response_model=TransactionResponse)
def get_transaction(tx_id: str):
    if tx_id in transactions_db:
        return transactions_db[tx_id]
    return {"error": "Transaction not found"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)