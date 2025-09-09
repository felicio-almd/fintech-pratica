#!/bin/bash
set -e

CLUSTER_NAME="fintech-cluster-local"

echo "--- Iniciando Ambiente de Teste com Kubernetes Local ---"

echo ""
echo "1. Iniciando contêineres de backend (Postgres e Redis)..."
docker-compose up -d postgres redis

echo ""
echo "2. Construindo as imagens Docker da aplicação..."
docker build -t transaction-api:latest ./docker/transaction-api
docker build -t notification-service:latest ./docker/notification-service
echo "✅ Imagens construídas."

echo ""
echo "3. Aguardando serviços de backend ficarem saudáveis..."
services="postgres redis"
for service in $services; do
    echo -n "Esperando o serviço '$service'... "
    timeout=60
    while [[ "$(docker-compose ps -q $service | xargs docker inspect -f '{{ .State.Health.Status }}')" != "healthy" ]]; do
        if [ $timeout -eq 0 ]; then
            echo "❌ Timeout! O serviço $service não ficou saudável a tempo."
            exit 1
        fi
        sleep 2
        timeout=$((timeout-2))
    done
    echo "✅"
done

echo ""
echo "4. Criando cluster Kubernetes local com Kind..."
kind create cluster --name $CLUSTER_NAME

echo ""
echo "5. Carregando imagens Docker para dentro do cluster Kind..."
kind load docker-image transaction-api:latest --name $CLUSTER_NAME
kind load docker-image notification-service:latest --name $CLUSTER_NAME
echo "✅ Imagens carregadas."

echo ""
echo "6. Criando o namespace 'fintech' e os Secrets no cluster..."
kubectl apply -f k8s/namespaces/

kubectl create secret generic postgres-connection -n fintech \
  --from-literal=endpoint='host.docker.internal' \
  --from-literal=port='5432' \
  --from-literal=username='user' \
  --from-literal=password='password'

kubectl create secret generic redis-connection -n fintech \
  --from-literal=endpoint='host.docker.internal' \
  --from-literal=port='6379'
echo "✅ Namespace e Secrets criados."

echo ""
echo "7. Fazendo deploy das aplicações no cluster Kind..."
kubectl apply -f k8s/apps/notification-service/
kubectl apply -f k8s/apps/transaction-api/
kubectl apply -f k8s/security/
kubectl apply -f k8s/autoscaling/

echo ""
echo "8. Aguardando os deployments da aplicação ficarem prontos..."
kubectl wait --for=condition=Available deployment/transaction-api -n fintech --timeout=120s
kubectl wait --for=condition=Available deployment/notification-service -n fintech --timeout=120s
echo "✅ Aplicação pronta no Kubernetes."

echo ""
echo "9. Executando testes de integração..."
if [ -f "./scripts/test.sh" ]; then
    chmod +x ./scripts/test.sh
    ./scripts/test.sh
else
    echo "Aviso: script 'test.sh' não encontrado. Pulando testes."
fi

echo ""
echo "--- Ambiente Kubernetes Local em Execução ---"
echo "Use 'kubectl get all -n fintech' para ver os recursos."
echo "Para limpar o ambiente, execute: ./scripts/cleanup-k8s-local.sh"
