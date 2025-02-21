#!/bin/bash

frontend_create_manifest() {
  print_banner
  printf "${WHITE} 💻 Criando manifest.json...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2

sudo su - deploy << EOF
  cat > /home/deploy/${instancia_add}/frontend/public/manifest.json << MANIFESTEOF
{
  "short_name": "${empresa_nome}",
  "name": "${empresa_nome}",
  "icons": [
    {
      "src": "favicon.ico",
      "sizes": "64x64 32x32 24x24 16x16",
      "type": "image/x-icon"
    },
    {
      "src": "logo192.png",
      "type": "image/png",
      "sizes": "192x192"
    },
    {
      "src": "logo512.png",
      "type": "image/png",
      "sizes": "512x512"
    }
  ],
  "start_url": ".",
  "display": "standalone",
  "theme_color": "#000000",
  "background_color": "#ffffff"
}
MANIFESTEOF
EOF
  sleep 2
}

frontend_node_dependencies() {
  print_banner
  printf "${WHITE} 💻 Instalando dependências do frontend...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  sudo su - deploy <<EOF
  cd /home/deploy/${instancia_add}/frontend
  npm install --legacy-peer-deps
EOF
  sleep 2
}

frontend_node_build() {
  print_banner
  printf "${WHITE} 💻 Compilando o código do frontend...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Build
  sudo su - deploy <<EOF
  cd /home/deploy/${instancia_add}/frontend
  npm run build
  rm -rf src
EOF

  # Ajustar permissões
  sudo su - root <<EOF
  chown -R deploy:deploy /home/deploy/${instancia_add}/
  chmod -R 755 /home/deploy/${instancia_add}/frontend/build/
  usermod -a -G deploy www-data
EOF

  sleep 2
}

frontend_set_env() {
  print_banner
  printf "${WHITE} 💻 Configurando variáveis de ambiente (frontend)...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2

  # Remove o protocolo e o caminho da URL do frontend
  frontend_url=$(echo "${frontend_url/https:\/\/}")
  frontend_url=${frontend_url%%/*}
  frontend_url=https://$frontend_url

  # Extrai o host do backend_url
  backend_host=$(echo "${backend_url/https:\/\/}")
  backend_host=${backend_host%%/*}

  sudo su - deploy << EOF1
  cat <<-EOF2 > /home/deploy/${instancia_add}/frontend/.env
REACT_APP_BACKEND_URL=${backend_url}
REACT_APP_FRONTEND_URL=${frontend_url}
REACT_APP_BACKEND_PROTOCOL=https
REACT_APP_BACKEND_HOST=${backend_host}
REACT_APP_BACKEND_PORT=443
REACT_APP_HOURS_CLOSE_TICKETS_AUTO=24
REACT_APP_LOCALE=pt-br
REACT_APP_TIMEZONE=America/Sao_Paulo
EOF2
EOF1
  sleep 2
}

frontend_nginx_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando nginx (frontend)...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  frontend_hostname=$(echo "${frontend_url/https:\/\/}")

sudo su - root << EOF
cat > /etc/nginx/sites-available/${instancia_add}-frontend << 'END'
server {
  server_name $frontend_hostname;
  
  root /home/deploy/${instancia_add}/frontend/build;
  index index.html;

  location / {
    try_files \$uri /index.html;
  }
}
END

ln -s /etc/nginx/sites-available/${instancia_add}-frontend /etc/nginx/sites-enabled
EOF

  sleep 2
}


frontend_setup() {
  frontend_set_env
  frontend_create_manifest
  frontend_node_dependencies
  frontend_node_build
  frontend_nginx_setup
}