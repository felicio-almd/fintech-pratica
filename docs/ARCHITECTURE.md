# Arquitetura do Projeto Fintech

Este documento detalha a arquitetura da aplicação de microserviços Fintech, cobrindo desde a infraestrutura na nuvem até a camada de aplicação e comunicação.

## Visão Geral

A arquitetura é baseada em um padrão de microserviços orquestrados pelo Kubernetes. A infraestrutura de nuvem subjacente é provisionada de forma declarativa usando o Crossplane, garantindo consistência e reprodutibilidade.

A aplicação consiste em dois serviços principais:
- **Transaction API**: O serviço de frontend para o cliente, responsável por criar e consultar transações.
- **Notification Service**: Um serviço de backend que processa eventos de novas transações e gera notificações.

O diagrama abaixo ilustra os principais componentes e o fluxo de comunicação:

```
      ┌─────────────────────────────────────────────────────────────────────────┐
      │                                AWS Cloud                                │
      │                                                                         │
      │   ┌──────────────────────────┐      ┌────────────────────────────────┐  │
      │   │     Amazon RDS (PostgreSQL)    │      │   Amazon ElastiCache (Redis)   │  │
      │   └─────────────▲────────────┘      └────────────────▲───────────────┘  │
      │                 │                                    │                  │
      └─────────────────┼────────────────────────────────────┼──────────────────┘
                        │                                    │
                        │ DB & Cache Connections             │
   ┌────────────────────┼────────────────────────────────────┼───────────────────┐
   │                    ▼                                    ▼                   │
   │  ┌───────────────────────────────────────────────────────────────────────┐  │
   │  │                           Cluster Kubernetes (EKS)                    │  │
   │  │                                                                       │  │
   │  │   ┌─────────────────────────┐      ┌────────────────────────────────┐   │  │
   │  │   │      Deployment         │      │         Deployment           │   │  │
   │  │   │ (Transaction API Pods)  │──────┼─────►│ (Notification Svc Pods)  │   │  │
   │  │   └─────────────▲───────────┘ Webhook└────────────────────────────────┘   │  │
   │  └─────────────────┼───────────────────────────────────────────────────────┘  │
   │                    │ Service Discovery                                        │
   │  ┌─────────────────┴──────────────────┐                                       │
   │  │         Ingress Controller         │                                       │
   │  └─────────────────▲──────────────────┘                                       │
   │                    │                                                          │
   └────────────────────┼──────────────────────────────────────────────────────────┘
                        │ HTTPS
                        │
                    Usuário Final

```

## Camada de Infraestrutura (Infrastructure Layer)

A infraestrutura é gerenciada como código (IaC) usando o **Crossplane**.

- **`CompositeResourceDefinition (XRD)`**: O arquivo `crossplane/xrds/fintech-xrd-complete.yaml` define um novo tipo de recurso no Kubernetes, o `XFintechPlatform`. Ele cria uma API customizada e abstrata para nossa plataforma, permitindo que desenvolvedores solicitem uma infraestrutura completa com parâmetros simples (como região da AWS, tamanho da instância do banco, etc.).

- **`Composition`**: O arquivo `crossplane/compositions/aws-complete.yaml` é o "molde" que implementa a `XFintechPlatform`. Ele define, usando a sintaxe de `Pipeline` do Crossplane, todos os recursos da AWS que compõem a nossa plataforma:
    - **Rede**: VPC, Sub-redes públicas e privadas, Internet Gateway, e Tabelas de Rota.
    - **Segurança**: Security Groups que funcionam como firewalls para cada componente.
    - **Banco de Dados**: Uma instância do Amazon RDS for PostgreSQL, configurada para alta disponibilidade (Multi-AZ).
    - **Cache**: Um cluster Amazon ElastiCache for Redis, também com alta disponibilidade.
    - **Computação**: Um cluster Amazon EKS (Elastic Kubernetes Service) que servirá como ambiente de execução para os microserviços.
    - **Outros**: Application Load Balancer, segredos no AWS Secrets Manager, zona de DNS no Route53 e grupos de logs no CloudWatch.

- **`ProviderConfig`**: Configura a conexão segura entre o Crossplane e a conta da AWS, utilizando um `Secret` do Kubernetes que armazena as credenciais da AWS.

## Camada de Aplicação (Application Layer)

A camada de aplicação roda inteiramente dentro do cluster Kubernetes provisionado pelo Crossplane.

- **Contêineres**: Cada microserviço (escrito em Python com FastAPI) é empacotado em uma imagem de contêiner Docker. Os `Dockerfiles` utilizam **multi-stage builds** para criar imagens otimizadas, seguras (rodando com usuário não-root) e pequenas.

- **Manifestos Kubernetes**: A implantação e configuração dos serviços no cluster são definidas por manifestos YAML:
    - **`Deployments`**: Gerenciam os Pods de cada aplicação, garantindo que o número desejado de réplicas esteja sempre em execução. Incluem `livenessProbes` e `readinessProbes` para garantir a saúde das aplicações e `resource limits` para um uso controlado de recursos.
    - **`Services`**: Expõem os Deployments como um serviço de rede, fornecendo um ponto de acesso estável e service discovery interno no cluster.
    - **`HorizontalPodAutoscaler (HPA)`**: Escala automaticamente o número de pods de cada serviço com base no uso de CPU, garantindo performance sob alta carga e economia de recursos em baixa carga.
    - **`NetworkPolicies`**: Implementam um firewall a nível de aplicação, restringindo a comunicação entre os pods a apenas o que é estritamente necessário (ex: `transaction-api` pode falar com `notification-service`, mas não o contrário).
    - **`Ingress`**: (A ser configurado) Gerencia o tráfego externo para o cluster, roteando requisições para os serviços apropriados.

## Comunicação e Fluxos

- **Comunicação Externa**: O tráfego de usuários entra no cluster através do **Ingress Controller**, que o direciona para o serviço relevante (inicialmente, o `transaction-api`).
- **Comunicação Interna**:
    - **Service Discovery**: Os serviços se encontram usando os nomes dos `Services` do Kubernetes (ex: `http://transaction-api:8080`).
    - **Webhooks**: A comunicação da `transaction-api` para o `notification-service` é feita de forma assíncrona via um webhook. Quando uma transação é criada, a API de transações envia uma requisição POST para o endpoint `/webhooks/new-transaction` do serviço de notificação. Isso desacopla os serviços.
