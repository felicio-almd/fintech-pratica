# Guia de Deploy

Este guia fornece um passo a passo completo para configurar e implantar a plataforma Fintech em um novo ambiente, desde a configuração da nuvem até o deploy da aplicação.

## 1. Pré-requisitos

Antes de começar, garanta que as seguintes ferramentas de linha de comando estejam instaladas e configuradas em sua máquina:

- `git`
- `docker`
- `kubectl`
- `kind`
- `helm`
- `aws-cli`

## 2. Configuração da Conta AWS

A plataforma utiliza o Crossplane para provisionar recursos na AWS. Portanto, uma conta AWS é necessária.

### 2.1. Crie um Usuário IAM

1.  Faça login no seu console da AWS e navegue até o serviço **IAM**.
2.  Crie um novo usuário com **acesso programático**.
3.  Anexe a política `AdministratorAccess` a este usuário.
    > **Nota**: Para ambientes de produção, é fortemente recomendado criar uma política customizada com permissões mínimas, permitindo apenas as ações que a `Composition` do Crossplane necessita (gerenciar EC2, RDS, EKS, etc.).
4.  Salve a **Access key ID** e a **Secret access key**.

### 2.2. Configure o AWS CLI

Configure o AWS CLI localmente com as credenciais do usuário criado no passo anterior:
```bash
aws configure
```
Isso armazenará suas credenciais no arquivo `~/.aws/credentials`.

## 3. Setup do Ambiente Local

Vamos criar um cluster Kubernetes local usando o `kind`.

```bash
# 1. Cria o cluster local
kind create cluster --name fintech-cluster

# 2. Instala o Ingress NGINX Controller para gerenciar o acesso externo
# A instalação pode levar um ou dois minutos para ser concluída.
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
```

## 4. Instalação e Configuração do Crossplane

Com o cluster no ar, vamos instalar e configurar o Crossplane.

```bash
# 1. Adiciona o repositório Helm do Crossplane
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# 2. Instala o Crossplane no namespace 'crossplane-system'
helm install crossplane --namespace crossplane-system --create-namespace crossplane-stable/crossplane

# 3. Cria o Secret com as credenciais da AWS para o Crossplane usar
kubectl create secret generic aws-secret \
  -n crossplane-system \
  --from-file=creds=~/.aws/credentials

# 4. Aplica a configuração do Provider AWS
kubectl apply -f crossplane/providers/aws-provider.yaml
kubectl apply -f crossplane/providers/aws-config.yaml
```

## 5. Provisionamento da Infraestrutura na Nuvem

Este é o passo que efetivamente cria os recursos na AWS.

> **⚠️ AVISO DE CUSTO**: Os comandos a seguir criarão recursos **reais e tarifados** na sua conta AWS. O processo completo pode levar de **15 a 25 minutos**.

```bash
# 1. Aplica a definição da nossa plataforma (XRD)
kubectl apply -f crossplane/xrds/

# 2. Aplica a composição de recursos (Composition)
kubectl apply -f crossplane/compositions/

# 3. Solicita a criação de UMA instância da plataforma
kubectl apply -f crossplane/instances/
```

Para acompanhar o progresso, abra um novo terminal e execute:
```bash
# Observe os recursos de alto nível sendo criados e ficando prontos (READY=True)
kubectl get composite -w

# Para uma visão mais detalhada dos recursos individuais na AWS:
watch kubectl get managed
```
**Aguarde o status de `READY` ser `True` antes de prosseguir.**

## 6. Deploy da Aplicação

Uma vez que a infraestrutura na nuvem está pronta, use nosso script automatizado para fazer o deploy dos microserviços.

```bash
# Dê permissão de execução para o script (só precisa na primeira vez)
chmod +x scripts/build-and-deploy.sh

# Execute o script
./scripts/build-and-deploy.sh
```
O script irá construir as imagens Docker, carregá-las no cluster `kind` e aplicar todos os manifestos Kubernetes necessários (Deployments, Services, HPAs, NetworkPolicies, etc.).

## 7. Testando a Aplicação

O script de deploy exibirá o status final dos recursos. Para testar a aplicação, você pode usar o Ingress, que no `kind` geralmente responde em `http://localhost`.

```bash
# Exemplo: Criar uma nova transação
curl -X POST http://localhost/transactions \
  -H "Content-Type: application/json" \
  -d '{"amount": 59.99, "user_id": "user-xyz-987", "description": "Assinatura mensal"}'

# Exemplo: Consultar as notificações para o usuário (pode levar alguns segundos)
curl http://localhost/notifications/user-xyz-987
```

## 8. Limpeza Total (Cleanup)

Para evitar cobranças contínuas, é **essencial** destruir todos os recursos na ordem correta.

### Passo 8.1: Destruir a Infraestrutura na Nuvem

**NÃO PULE ESTE PASSO.** Você deve mandar o Crossplane apagar os recursos da AWS antes de desligar o cluster local.

```bash
# 1. Mande o Crossplane deletar a instância da plataforma
kubectl delete -f crossplane/instances/

# 2. Monitore a exclusão. Espere até que o comando não retorne mais nada.
# Isso pode levar vários minutos.
watch kubectl get managed
```

### Passo 8.2: Destruir o Cluster Local

Apenas quando o comando `watch` do passo anterior não mostrar mais nenhum recurso, destrua o cluster `kind`:
```bash
kind delete cluster --name fintech-cluster
```
