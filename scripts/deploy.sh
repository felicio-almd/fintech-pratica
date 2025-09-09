#!/bin/bash
set -e

echo "build das imagens Docker"
cd docker/transaction-api
docker build -t transaction-api .
cd ../notification-service
docker build -t notification-service .
cd ../..

echo "carregando imagens no Kind"
kind load docker-image transaction-api --name fintech-cluster
kind load docker-image notification-service --name fintech-cluster

echo "- Fazendo deploy no Kubernetes"

# Deploy namespaces primeiro
echo "-- Criando namespaces --"
kubectl apply -f k8s/namespaces/

# Deploy aplicações
echo "-- Deploy das aplicações --"
kubectl apply -f k8s/apps/

# Deploy security policies
if [ -d "k8s/security" ] && [ "$(ls -A k8s/security)" ]; then
    echo "-- Deploy das politicas de rede --"
    kubectl apply -f k8s/security/
else
    echo " Pasta security vazia ou não encontrada"
fi

# Deploy monitoring (se existir)
if [ -d "k8s/monitoring" ] && [ "$(ls -A k8s/monitoring)" ]; then
    echo "-- Deploy do monitoring"
    kubectl apply -f k8s/monitoring/
else
    echo " Pasta monitoring vazia ou não encontrada"
fi

# Deploy autoscaling (se existir)
if [ -d "k8s/autoscaling" ] && [ "$(ls -A k8s/autoscaling)" ]; then
    echo "-- Deploy do autoscaling --"
    kubectl apply -f k8s/autoscaling/
else
    echo " Pasta autoscaling vazia ou não encontrada"
fi

kubectl wait --for=condition=Ready pod -l app=transaction-api -n fintech --timeout=60s || true
kubectl wait --for=condition=Ready pod -l app=notification-service -n fintech --timeout=60s || true

echo "- Deploy concluído"
echo ""
echo "- Status dos pods:"
kubectl get pods -n fintech

echo ""
echo "- Status dos services:"
kubectl get services -n fintech


echo ""
echo "- Status do HPA:"
kubectl get hpa -n fintech

echo ""
echo "-- Para testar as APIs:"
echo "kubectl port-forward -n fintech svc/transaction-api 8080:8080 &"
echo "kubectl port-forward -n fintech svc/notification-service 8081:8081 &"
echo "curl http://localhost:8080/health"
echo "curl http://localhost:8081/health"
