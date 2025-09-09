# Projeto Fintech: Aplicação de Microserviços com Kubernetes e Crossplane

Este projeto é um estudo de caso prático que aborda o ciclo de vida completo de uma aplicação de microserviços, desde a codificação em Python até a implantação, orquestração e provisionamento de infraestrutura na nuvem.

---

## 📝 Descrição

A aplicação simula um sistema de **Fintech** simples, composto por dois serviços independentes:

- **Transaction API**: Responsável por receber, criar e consultar transações financeiras.
- **Notification Service**: Responsável por simular o envio de notificações (ex: email, push) relacionadas às transações.

O objetivo principal é demonstrar as melhores práticas de **DevOps** e **engenharia de nuvem**, incluindo:

- Containerização com **Docker**.
- Orquestração com **Kubernetes**.
- Infraestrutura como Código (IaC) com **Crossplane**.
- Automação com **Shell Scripts**.
- Observabilidade com **Prometheus** e **Grafana**.

---

## 🏛️ Arquitetura

A arquitetura do projeto está detalhada em [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md).

---

## 🚀 Como Executar o Projeto

Você pode executar este projeto de três formas, dependendo do seu objetivo.

### Opção 1: Modo Docker Compose (Local, Rápido e Simples)

Ideal para desenvolvimento e testes rápidos da **aplicação**, sem a complexidade do Kubernetes ou custos de nuvem. Orquestra os microserviços, um banco de dados e o Redis diretamente com o Docker.

- **Pré-requisitos:** `docker`, `docker-compose`
- **Para iniciar:**
  ```bash
  # Dê permissão de execução ao script (apenas uma vez)
  chmod +x ./scripts/run-local.sh

  # Inicie o ambiente e execute os testes
  ./scripts/run-local.sh
  ```
- **Para limpar:** Pressione `Ctrl+C` no terminal onde o script está rodando. O script se encarregará de desligar e remover os contêineres.

---

### Opção 2: Modo Kubernetes Local (Simulação do Ambiente de Nuvem)

Ideal para testar os **manifestos de orquestração** do Kubernetes (`Deployments`, `Services`, `HPA`, etc.) em um ambiente que simula a nuvem, mas sem custos. Usa o `kind` para criar um cluster Kubernetes local e o `Docker Compose` para rodar as dependências (Postgres, Redis).

- **Pré-requisitos:** `docker`, `docker-compose`, `kind`, `kubectl`
- **Para iniciar:**
  ```bash
  # Dê permissão de execução ao script (apenas uma vez)
  chmod +x ./scripts/run-k8s-local.sh

  # Inicie o ambiente e execute os testes
  ./scripts/run-k8s-local.sh
  ```
- **Para limpar:**
  ```bash
  # Dê permissão de execução ao script (apenas uma vez)
  chmod +x ./scripts/cleanup-k8s-local.sh

  # Execute o script de limpeza
  ./scripts/cleanup-k8s-local.sh
  ```

---

### Opção 3: Modo Nuvem (Deploy Completo na AWS)

Este é o modo de produção completo. Provisiona toda a infraestrutura real na AWS usando **Crossplane** e implanta os microserviços em um cluster **EKS** gerenciado.

- **Pré-requisitos:** `docker`, `kind`, `kubectl`, `helm`, `aws-cli`
- **Guia de Deploy Detalhado:** Siga as instruções em [`docs/DEPLOYMENT.md`](./docs/DEPLOYMENT.md) para a configuração completa.
- **Comandos Resumidos:**
  1.  **Preparar e Provisionar:** Siga os passos do guia de deploy para configurar suas credenciais da AWS e provisionar a infraestrutura com `kubectl apply`.
      > **AVISO**: Este passo cria recursos que geram **custos** na sua conta AWS.
  2.  **Implantar a Aplicação:**
      ```bash
      chmod +x ./scripts/build-and-deploy.sh
      ./scripts/build-and-deploy.sh
      ```
  3.  **Testar a Aplicação:**
      ```bash
      chmod +x ./scripts/test.sh
      ./scripts/test.sh
      ```
- **Para limpar:**
    > **IMPORTANTE**: Use este script para garantir que todos os recursos na nuvem sejam destruídos e evitar cobranças.
    ```bash
    chmod +x ./scripts/cleanup.sh
    ./scripts/cleanup.sh
    ```

---

## 📚 Documentação Adicional

- **Arquitetura Detalhada**: [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md)
- **Documentação da API**: [`docs/API.md`](./docs/API.md)
- **Guia de Deploy na Nuvem**: [`docs/DEPLOYMENT.md`](./docs/DEPLOYMENT.md)
