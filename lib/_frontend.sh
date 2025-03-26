#!/bin/bash

frontend_create_manifest() {
  print_banner
  printf "${WHITE} 💻 Criando manifest.json...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2

  # Verificar se o diretório existe
  if [ ! -d "/home/deploy/empresa/frontend/public" ]; then
    printf "\n${RED} ⚠️ Diretório do frontend não encontrado.${GRAY_LIGHT}"
    sudo mkdir -p /home/deploy/empresa/frontend/public
    sudo chown -R deploy:deploy /home/deploy/empresa/frontend
  fi

  sudo -u deploy bash -c "cat > /home/deploy/empresa/frontend/public/manifest.json << MANIFESTEOF
{
  \"short_name\": \"${empresa_nome}\",
  \"name\": \"${empresa_nome}\",
  \"icons\": [
    {
      \"src\": \"favicon.ico\",
      \"sizes\": \"64x64 32x32 24x24 16x16\",
      \"type\": \"image/x-icon\"
    },
    {
      \"src\": \"logo192.png\",
      \"type\": \"image/png\",
      \"sizes\": \"192x192\"
    },
    {
      \"src\": \"logo512.png\",
      \"type\": \"image/png\",
      \"sizes\": \"512x512\"
    }
  ],
  \"start_url\": \".\",
  \"display\": \"standalone\",
  \"theme_color\": \"#000000\",
  \"background_color\": \"#ffffff\"
}
MANIFESTEOF"

  sleep 2
}

frontend_node_dependencies() {
  print_banner
  printf "${WHITE} 💻 Instalando dependências do frontend...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Verificar se o diretório existe
  if [ ! -d "/home/deploy/empresa/frontend" ]; then
    printf "\n${RED} ⚠️ Diretório do frontend não encontrado.${GRAY_LIGHT}"
    printf "\n\n"
    sleep 5
    return 1
  fi
  
  # Instalar dependências
  sudo -u deploy bash -c "cd /home/deploy/empresa/frontend && npm install --legacy-peer-deps"
  
  # Verificar resultado
  if [ $? -ne 0 ]; then
    printf "\n${RED} ⚠️ Erro ao instalar dependências do frontend${GRAY_LIGHT}"
    printf "\n${YELLOW} Tentando novamente...${GRAY_LIGHT}"
    sudo -u deploy bash -c "cd /home/deploy/empresa/frontend && npm cache clean --force && npm install --legacy-peer-deps --force"
  fi

  printf "\n${GREEN} ✅ Dependências do frontend instaladas!${GRAY_LIGHT}"
  sleep 2
}

frontend_node_build() {
  print_banner
  printf "${WHITE} 💻 Compilando o código do frontend...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Verificar se o diretório node_modules existe
  if [ ! -d "/home/deploy/empresa/frontend/node_modules" ]; then
    printf "\n${YELLOW} ⚠️ Diretório node_modules não encontrado. Executando npm install novamente...${GRAY_LIGHT}"
    sudo -u deploy bash -c "cd /home/deploy/empresa/frontend && npm install --legacy-peer-deps"
  fi
  
  # Executar build
  sudo -u deploy bash -c "cd /home/deploy/empresa/frontend && npm run build"
  
  # Verificar se o build foi concluído com sucesso
  if [ ! -d "/home/deploy/empresa/frontend/build" ]; then
    printf "\n${RED} ⚠️ Falha ao compilar o código do frontend.${GRAY_LIGHT}"
    return 1
  fi
  
  # Ajustar permissões
  sudo chown -R deploy:deploy /home/deploy/empresa/frontend/build
  sudo chmod -R 755 /home/deploy/empresa/frontend/build
  
  printf "\n${GREEN} ✅ Código do frontend compilado com sucesso!${GRAY_LIGHT}"
  sleep 2
}

frontend_set_env() {
  print_banner
  printf "${WHITE} 💻 Configurando variáveis de ambiente (frontend)...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2

  # Verificar se o diretório existe
  if [ ! -d "/home/deploy/empresa/frontend" ]; then
    printf "\n${RED} ⚠️ Diretório do frontend não encontrado.${GRAY_LIGHT}"
    printf "\n\n"
    sleep 5
    return 1
  fi

  # Processamento das URLs
  frontend_url_clean=$(echo "${frontend_url}" | sed 's~^https://~~')
  frontend_url_clean=${frontend_url_clean%%/*}
  frontend_url_full="https://$frontend_url_clean"

  backend_host=$(echo "${backend_url}" | sed 's~^https://~~')
  backend_host=${backend_host%%/*}

  sudo -u deploy bash -c "cat > /home/deploy/empresa/frontend/.env << EOF
REACT_APP_BACKEND_URL=${backend_url}
REACT_APP_FRONTEND_URL=${frontend_url_full}
REACT_APP_BACKEND_PROTOCOL=https
REACT_APP_BACKEND_HOST=${backend_host}
REACT_APP_BACKEND_PORT=443
REACT_APP_HOURS_CLOSE_TICKETS_AUTO=24
REACT_APP_LOCALE=pt-br
REACT_APP_TIMEZONE=America/Sao_Paulo
EOF"

  sleep 2
}

frontend_nginx_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando nginx (frontend)...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2

  frontend_hostname=$(echo "${frontend_url}" | sed 's~^https://~~')

  sudo bash -c "cat > /etc/nginx/sites-available/empresa-frontend << EOF
server {
  server_name ${frontend_hostname};
  
  root /home/deploy/empresa/frontend/build;
  index index.html;

  location / {
    try_files \\\$uri /index.html;
  }
}
EOF"

  sudo ln -sf /etc/nginx/sites-available/empresa-frontend /etc/nginx/sites-enabled/
  sleep 2
}

frontend_setup() {
  frontend_set_env
  frontend_create_manifest
  frontend_node_dependencies
  frontend_node_build
  frontend_nginx_setup
}