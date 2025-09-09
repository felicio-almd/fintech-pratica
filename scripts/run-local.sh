#!/bin/bash
set -e

# Garante que o docker-compose down seja executado ao sair do script
cleanup() {
    echo ""
    echo "Encerrando o ambiente local..."
    docker-compose down -v --remove-orphans
    echo "Ambiente local encerrado."
}
trap cleanup EXIT INT TERM

echo "--- Iniciando Ambiente de Desenvolvimento Local com Docker Compose ---"

echo "1. Construindo e iniciando os contêineres em background..."
docker-compose up --build -d

echo ""
echo "2. Aguardando os serviços ficarem saudáveis (pode levar até um minuto)..."

# Loop para esperar que todos os serviços estejam saudáveis
services=$(docker-compose ps --services)
for service in $services; do
    echo -n "Esperando o serviço '$service'... "
    # Espera até 60 segundos para o serviço ficar saudável
    timeout=60
    while [[ "$(docker-compose ps -q $service | xargs docker inspect -f '{{ .State.Health.Status }}')" != "healthy" ]]; do
        if [ $timeout -eq 0 ]; then
            echo "❌ Timeout! O serviço $service não ficou saudável a tempo."
            echo "Logs do serviço $service:"
            docker-compose logs $service
            exit 1
        fi
        sleep 2
        timeout=$((timeout-2))
    done
    echo "✅"
done

echo "
✅ Ambiente local iniciado com sucesso."
echo ""

echo "3. Executando o script de teste de integração..."
if [ -f "./scripts/test.sh" ]; then
    chmod +x ./scripts/test.sh
    ./scripts/test.sh
else
    echo "Aviso: script 'test.sh' não encontrado. Pulando testes."
fi

echo ""
echo "--- Ambiente Local em Execução ---"
echo "Use 'docker-compose logs -f' para ver os logs em tempo real."
echo "Pressione Ctrl+C a qualquer momento para encerrar este script e o ambiente."

# Mantém o script rodando para que a trap de cleanup funcione ao fechar
tail -f /dev/null
