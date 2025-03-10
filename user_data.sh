#!/bin/bash

# Atualizar pacotes do sistema
sudo apt-get update -y && sudo apt-get upgrade -y

# Instalar pacotes necessários
sudo apt-get install -y docker.io curl

# Habilitar e iniciar Docker
sudo systemctl enable --now docker

# Baixar e instalar Docker Compose
DOCKER_COMPOSE_VERSION="2.20.2" 
DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
sudo curl -L "$DOCKER_COMPOSE_URL" -o /usr/local/bin/docker-compose

# Tornar o Docker Compose executável
sudo chmod +x /usr/local/bin/docker-compose

# Adicionar usuário ao grupo Docker
USER_NAME=$(whoami)  # Obtém o usuário atual
sudo usermod -aG docker "$USER_NAME"

# Verificar se o Docker está rodando corretamente
if systemctl is-active --quiet docker; then
    echo "Docker está rodando com sucesso!"
else
    echo "Erro ao iniciar o Docker."
    exit 1
fi
