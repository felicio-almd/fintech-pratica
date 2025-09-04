FROM python:3.11-slim

# Instalar dependências
WORKDIR /app
COPY . .
RUN pip install flask

# Expor porta
EXPOSE 5000

# Comando para rodar
CMD ["python", "app.py"]