#!/bin/bash
set -e

echo "#####################################################################"
echo "# ATENÇÃO: Iniciando a destruição de TODA a infraestrutura.         #"
echo "#####################################################################"
echo ""

echo "--> Passo 1 de 3: Enviando comando para deletar a infraestrutura na AWS..."
echo "Isto pode levar vários minutos. O Crossplane está comandando a AWS para remover os recursos."
kubectl delete -f crossplane/instances/
echo "Comando de exclusão enviado."
echo ""

echo "--> Passo 2 de 3: Monitorando a exclusão dos recursos na nuvem..."
echo "O script irá monitorar por até 20 minutos."
echo "Se o processo demorar mais, você terá que verificar manualmente no console da AWS."
echo ""

# Espera até que os recursos gerenciados sejam excluídos, com um timeout.
timeout=1200 # 20 minutos
interval=30  # 30 segundos
elapsed=0

while (( elapsed < timeout )); do
  # O || true evita que o script pare se o grep não encontrar nada
  count=$(kubectl get managed 2>/dev/null | grep -v "NAME" | wc -l || true)
  if [ "$count" -eq 0 ]; then
    echo "Todos os recursos gerenciados foram removidos com sucesso."
    break
  fi
  echo "Ainda esperando a remoção de $count recurso(s) gerenciado(s)... (verificando a cada $interval segundos)"
  sleep $interval
  elapsed=$((elapsed + interval))
done

if (( elapsed >= timeout )); then
  echo "ATENÇÃO: Timeout atingido! Verifique o console da AWS para garantir que todos os recursos foram removidos antes de continuar."
  exit 1
fi


echo ""
echo "--> Passo 3 de 3: Deletando o cluster Kind local..."
kind delete cluster --name fintech-cluster

echo ""
echo "Limpeza concluída com sucesso."
