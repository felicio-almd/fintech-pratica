#!/bin/bash

# Função para limpar os processos em background ao sair
cleanup() {
    echo "
Encerrando processos de port-forward..."
    # O kill no PID do script que executa em background encerra os filhos
    if [ ! -z "$PORT_FORWARD_PID" ]; then
        kill $PORT_FORWARD_PID > /dev/null 2>&1
    fi
    exit
}

trap cleanup EXIT INT TERM

echo "--- Iniciando Script de Teste de Integração ---"

echo "1. Configurando port-forward para os serviços..."
# Inicia o port-forward em background
kubectl port-forward -n fintech svc/transaction-api 8080:8080 > /dev/null 2>&1 &
PORT_FORWARD_PID_TX=$!

kubectl port-forward -n fintech svc/notification-service 8081:8081 > /dev/null 2>&1 &
PORT_FORWARD_PID_NOTIF=$!

# Dar um tempo para o port-forward estabilizar
sleep 5

# Variáveis do Teste
API_URL="http://localhost:8080"
NOTIF_URL="http://localhost:8081"
USER_ID="test-user-$(date +%s)" # User ID único para cada teste
DESCRIPTION="teste-de-integracao"
AMOUNT=99.99

echo "2. Testando o endpoint de Health da API de Transação..."
if curl -s -f "${API_URL}/health" | grep -q '"status":"healthy"'; then
    echo "✅ Health check da API de Transação OK."
else
    echo "❌ Falha no Health check da API de Transação."
    exit 1
fi
echo ""

echo "3. Criando uma nova transação..."
RESPONSE=$(curl -s -X POST "${API_URL}/transactions" \
  -H "Content-Type: application/json" \
  -d "{\"amount\": ${AMOUNT}, \"user_id\": \"${USER_ID}\", \"description\": \"${DESCRIPTION}\"}")

if [ -z "$RESPONSE" ]; then
    echo "❌ Falha ao criar transação: Resposta vazia."
    exit 1
fi

# Extrai o ID usando grep e sed, para não depender do jq
TX_ID=$(echo $RESPONSE | grep -o '"id":"[^"]*' | sed 's/"id":"//')

if [ -z "$TX_ID" ]; then
    echo "❌ Falha ao extrair ID da transação da resposta: $RESPONSE"
    exit 1
else
    echo "✅ Transação criada com sucesso. ID: ${TX_ID}"
fi
echo ""

echo "4. Verificando a transação criada..."
sleep 2 # Pequena pausa para garantir que a transação seja processada
GET_RESPONSE=$(curl -s "${API_URL}/transactions/${TX_ID}")

if echo "$GET_RESPONSE" | grep -q "\"user_id\":\"${USER_ID}\""; then
    echo "✅ Transação recuperada com sucesso."
else
    echo "❌ Falha ao verificar a transação. Resposta recebida: $GET_RESPONSE"
    exit 1
fi
echo ""

echo "5. Verificando se o webhook de notificação foi processado..."
# Pausa para dar tempo ao webhook de ser processado
echo "   Aguardando 5 segundos pelo processamento do webhook..."
sleep 5

NOTIF_RESPONSE=$(curl -s "${NOTIF_URL}/notifications/${USER_ID}")

# Verifica se a resposta contém o ID da transação
if echo "$NOTIF_RESPONSE" | grep -q "\"transaction_id\":\"${TX_ID}\""; then
    echo "✅ Webhook de notificação recebido com sucesso!"
else
    echo "❌ Falha na verificação do webhook. Nenhuma notificação encontrada para o usuário ${USER_ID}."
    echo "   Resposta recebida: $NOTIF_RESPONSE"
    exit 1
fi
echo ""

echo "--- ✅ Todos os testes passaram com sucesso! ---"

# A trap no início do script cuidará de matar os processos de port-forward
kill $PORT_FORWARD_PID_TX
kill $PORT_FORWARD_PID_NOTIF
