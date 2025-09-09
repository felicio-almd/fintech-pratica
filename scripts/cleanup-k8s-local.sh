#!/bin/bash
set -e

CLUSTER_NAME="fintech-cluster-local"

echo "#####################################################################"
echo "# ATENÇÃO: Este script irá destruir o cluster Kind local e os       #"
echo "#          contêineres do Docker Compose (Postgres, Redis).         #"
echo "#####################################################################"
echo ""

echo "--> Passo 1 de 2: Deletando o cluster Kind '$CLUSTER_NAME'..."
kind delete cluster --name $CLUSTER_NAME

echo ""
echo "--> Passo 2 de 2: Parando e removendo os contêineres do Docker Compose..."
docker-compose down -v --remove-orphans

echo ""
echo "Limpeza do ambiente Kubernetes local concluída."
