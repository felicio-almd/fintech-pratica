# Projeto Fintech: Aplicação de Microserviços com Kubernetes

Este projeto é um estudo de caso prático que aborda o ciclo de vida completo de uma aplicação de microserviços, desde a codificação em Python até a implantação, orquestração e monitoramento em um ambiente Kubernetes.

---

## 📝 Descrição

A aplicação simula um sistema de **Fintech** simples, composto por dois serviços independentes:

- **Transaction API**: Responsável por receber, criar e consultar transações financeiras.  
- **Notification API**: Responsável por simular o envio de notificações (ex: email, push) relacionadas às transações.

O objetivo principal é demonstrar as melhores práticas de **DevOps** e **engenharia de nuvem**, incluindo:

- Containerização com **Docker**  
- Orquestração com **Kubernetes**  
- Automação com scripts  
- Observabilidade com **Prometheus** e **Grafana**

---

## 🏛️ Arquitetura

A arquitetura é baseada em microserviços, onde cada serviço é containerizado e implantado de forma independente no Kubernetes.

```
                  ┌───────────────────────────┐
                  │  Cluster Kubernetes (Kind) │
                  │                            │
Solicitação HTTP ─►│ Service (Load Balancer) ──┬─► Pod (Transaction API)
                  │                            │ │
                  │ Service (Load Balancer) ───┘─► Pod (Notification API)
                  │                            │
                  └───────────────────────────┘
```

---

## ✨ Funcionalidades

- Dois microserviços independentes: Transaction API e Notification API construídos com **FastAPI**.  
- **Containerização**: Cada serviço possui seu próprio `Dockerfile`.  
- **Orquestração com Kubernetes**: Manifestos `Deployment` e `Service` para cada API, garantindo escalabilidade e resiliência.  
- **Automação**: Scripts para build, test e cleanup.  
- **Infraestrutura como Código (IaC)**: Gerenciamento de um bucket **S3** na AWS via **Crossplane**.  
- **Monitoramento e Observabilidade**: Integração com a stack **kube-prometheus-stack** (Prometheus + Grafana).  

---

## 🛠️ Tecnologias Utilizadas

- **Backend**: Python 3.11, FastAPI  
- **Containerização**: Docker  
- **Orquestração**: Kubernetes (Kind)  
- **Gerenciamento de Pacotes K8s**: Helm  
- **Infraestrutura como Código**: Crossplane  
- **Monitoramento**: Prometheus, Grafana  
- **Linha de Comando**: kubectl, curl  

---

## ⚙️ Pré-requisitos

Antes de começar, garanta que você tenha as seguintes ferramentas instaladas:

- Docker  
- kubectl  
- Kind  
- Helm  

---

## 🚀 Como Executar o Projeto

### 1. Criar o Cluster Kubernetes Local
```bash
kind create cluster --name meu-primeiro-cluster
```

### 2. Construir e Carregar as Imagens Docker
```bash
./scripts/build-and-deploy.sh --build-only
```
Ou manualmente:
```bash
docker build -t transaction-api ./transaction-api
docker build -t notification-api ./notification-api
kind load docker-image transaction-api notification-api --name meu-primeiro-cluster
```

### 3. Implantar as Aplicações no Kubernetes
```bash
kubectl apply -f k8s/namespaces/namespace.yaml
kubectl apply -f k8s/apps/
```

### 4. Verificar a Implantação
```bash
kubectl get pods -n fintech
```
Você deverá ver 2 pods para a **transaction-api** e 2 para o **notification-service**.

### 5. Testar as APIs
```bash
# Em um terminal
kubectl port-forward -n fintech svc/transaction-api 8080:8080

# Em outro terminal
kubectl port-forward -n fintech svc/notification-service 8081:8081
```

Testando com `curl`:
```bash
# Testar a saúde da Transaction API
curl http://localhost:8080/health

# Criar uma nova transação
curl -X POST http://localhost:8080/transactions   -H "Content-Type: application/json"   -d '{"amount": 150.0, "user_id": "user456", "description": "Compra online"}'
```

---

## 📊 Monitoramento com Grafana

### Instalar a Stack de Monitoramento:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack   --namespace monitoring --create-namespace   --set grafana.adminPassword=admin
```

### Acessar o Grafana:
```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```
Acesse [http://localhost:3000](http://localhost:3000)  
Login: **admin**  
Senha: **admin**  

Explore dashboards como **Kubernetes / Compute Resources / Namespace (Pods)**.

---

## ☁️ Gerenciamento de Infraestrutura com Crossplane

O **Crossplane** está configurado para gerenciar recursos na AWS.

### Configurar Credenciais:
Crie o `Secret` do Kubernetes com suas credenciais da AWS e aplique o `ProviderConfig`.

### Criar um Bucket S3:
```bash
kubectl apply -f crossplane/s3-bucket.yaml
```

---

## 🧹 Limpeza do Ambiente

### Remover os recursos criados:
```bash
./scripts/cleanup.sh
```

### Deletar o cluster Kind:
```bash
kind delete cluster --name meu-primeiro-cluster
```

---
<br>
<br>

Autor: **Felicio Almeida**  
