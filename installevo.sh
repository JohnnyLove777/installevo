#!/bin/bash

# Função para solicitar informações ao usuário e armazená-las em variáveis
function solicitar_informacoes {

    # Loop para solicitar e verificar o dominio
    while true; do
        read -p "Digite o domínio (por exemplo, johnny.com.br): " DOMINIO
        # Verifica se o subdomínio tem um formato válido
        if [[ $DOMINIO =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo "Por favor, insira um domínio válido no formato, por exemplo 'johnny.com.br'."
        fi
    done    

    # Loop para solicitar e verificar o e-mail
    while true; do
        read -p "Digite o e-mail para cadastro do Certbot (sem espaços): " EMAIL
        # Verifica se o e-mail tem o formato correto e não contém espaços
        if [[ $EMAIL =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo "Por favor, insira um endereço de e-mail válido sem espaços."
        fi
    done

    # Geração da chave de autenticação segura
    AUTH_KEY=$(openssl rand -hex 16)
    echo "Sua chave de autenticação é: $AUTH_KEY"
    echo "Por favor, copie esta chave e armazene em um local seguro."
    
    while true; do
        read -p "Confirme que você copiou a chave (y/n): " confirm
        if [[ $confirm == "y" ]]; then
            break
        else
            echo "Por favor, copie a chave antes de continuar."
        fi
    done

    # Armazena as informações inseridas pelo usuário nas variáveis globais
    EMAIL_INPUT=$EMAIL
    DOMINIO_INPUT=$DOMINIO
    AUTH_KEY_INPUT=$AUTH_KEY
}

# Função para instalar a Evolution API de acordo com os comandos fornecidos
function instalar_evolution_api {
    # Atualização e upgrade do sistema
    #sudo apt update
    sudo apt upgrade -y
    sudo apt-add-repository universe

    # Instalação das dependências
    sudo apt install -y python2-minimal nodejs npm git curl apt-transport-https ca-certificates software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
    sudo apt update
    sudo apt install -y docker-ce docker-compose
    sudo apt update
    sudo apt install nginx
    sudo apt update
    sudo apt install certbot
    sudo apt install python3-certbot-nginx
    sudo apt update

    # Adiciona usuário ao grupo Docker
    sudo usermod -aG docker ${USER}

    # Solicita informações ao usuário
    solicitar_informacoes

    # Criação do arquivo evolution_api_config.sh com base nas informações fornecidas
cat <<EOF > evolution_api_config.sh
server {
    server_name evolution.$DOMINIO_INPUT;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Copia o arquivo de configuração para o diretório do nginx
sudo cp evolution_api_config.sh /etc/nginx/sites-available/evolution

# Cria link simbólico para ativar o site no nginx
sudo ln -s /etc/nginx/sites-available/evolution /etc/nginx/sites-enabled

# Solicita e instala certificados SSL usando Certbot
sudo certbot --nginx --email $EMAIL_INPUT --redirect --agree-tos -d evolution.$DOMINIO_INPUT

# Instalação e configuração da Evolution API usando Docker
docker run --name evolution-api --detach \
-p 8080:8080 \
-e AUTHENTICATION_API_KEY=$AUTH_KEY_INPUT \
atendai/evolution-api \
node ./dist/src/main.js

    echo "Evolution API instalada e configurada com sucesso!"
}

# Chamada das funções
instalar_evolution_api
