# Documentação da API

Este documento detalha os endpoints disponíveis nos microserviços da plataforma Fintech.

## Transaction API

Este serviço é o ponto de entrada principal para operações de transações.

---

### `POST /transactions`

Cria uma nova transação financeira. Após a criação, dispara um webhook para o serviço de notificação.

- **Método**: `POST`
- **Endpoint**: `/transactions`
- **Corpo da Requisição** (`application/json`):

```json
{
  "amount": 150.75,
  "user_id": "user-abc-123",
  "description": "Compra de livros online"
}
```

- **Resposta de Sucesso** (`201 Created`):

```json
{
  "id": "a1b2c3d4",
  "amount": 150.75,
  "user_id": "user-abc-123",
  "description": "Compra de livros online",
  "created_at": "2025-09-05T14:30:00.123Z",
  "status": "completed"
}
```

---

### `GET /transactions/{tx_id}`

Recupera os detalhes de uma transação específica pelo seu ID. Os resultados são cacheados no Redis por 1 hora para otimizar a performance.

- **Método**: `GET`
- **Endpoint**: `/transactions/<ID_DA_TRANSACAO>`
- **Parâmetro de URL**:
    - `tx_id` (string, obrigatório): O ID da transação a ser consultada.
- **Resposta de Sucesso** (`200 OK`):

```json
{
  "id": "a1b2c3d4",
  "amount": 150.75,
  "user_id": "user-abc-123",
  "description": "Compra de livros online",
  "created_at": "2025-09-05T14:30:00.123Z",
  "status": "completed"
}
```
- **Resposta de Erro** (`404 Not Found`):
```json
{
  "detail": "Transaction not found"
}
```

---

### `GET /health`

Endpoint de verificação de saúde, utilizado pelo Kubernetes (`livenessProbe` e `readinessProbe`).

- **Método**: `GET`
- **Endpoint**: `/health`
- **Resposta de Sucesso** (`200 OK`):
```json
{
  "status": "healthy",
  "service": "transaction-api"
}
```

---

### `GET /metrics`

Expõe métricas no formato Prometheus para serem coletadas pelo sistema de monitoramento.

- **Método**: `GET`
- **Endpoint**: `/metrics`
- **Resposta**: Texto plano com métricas, como `transactions_total`.

<br>

## Notification Service

Este serviço lida com a lógica de notificações e é acionado por eventos internos.

---

### `POST /webhooks/new-transaction`

Endpoint **interno** para receber notificações de novas transações via webhook da `Transaction API`.

- **Método**: `POST`
- **Endpoint**: `/webhooks/new-transaction`
- **Corpo da Requisição** (`application/json`): O corpo é o mesmo da resposta de criação de transação.

```json
{
  "id": "a1b2c3d4",
  "amount": 150.75,
  "user_id": "user-abc-123",
  "description": "Compra de livros online",
  "created_at": "2025-09-05T14:30:00.123Z",
  "status": "completed"
}
```

- **Resposta de Sucesso** (`202 Accepted`):
```json
{
  "status": "notification created"
}
```

---

### `GET /notifications/{user_id}`

Recupera todas as notificações geradas para um usuário específico.

- **Método**: `GET`
- **Endpoint**: `/notifications/<ID_DO_USUARIO>`
- **Parâmetro de URL**:
    - `user_id` (string, obrigatório): O ID do usuário.
- **Resposta de Sucesso** (`200 OK`): Uma lista de objetos de notificação.

```json
[
  {
    "id": "n1a2b3c4",
    "transaction_id": "a1b2c3d4",
    "user_id": "user-abc-123",
    "message": "Sua transação de R$ 150.75 (Compra de livros online) foi completed.",
    "status": "created",
    "created_at": "2025-09-05T14:30:01.456Z"
  }
]
```

---

### `GET /health`

Endpoint de verificação de saúde para o Kubernetes.

- **Método**: `GET`
- **Endpoint**: `/health`
- **Resposta de Sucesso** (`200 OK`):
```json
{
  "status": "healthy",
  "service": "notification-api"
}
```
