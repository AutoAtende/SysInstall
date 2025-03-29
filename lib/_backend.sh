#!/bin/bash

backend_redis_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando Redis para o backend...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Verificando se o Redis está rodando
  sudo systemctl status redis-server --no-pager
  
  if [ $? -ne 0 ]; then
    printf "\n${RED} ⚠️ Redis não está rodando. Tentando reiniciar...${GRAY_LIGHT}"
    sudo systemctl restart redis-server
    sleep 2
    sudo systemctl status redis-server --no-pager
  fi
  
  sleep 2
}

backend_set_env() {

backend_url_full=$(echo "${backend_url}" | grep -q "^https://" && echo "${backend_url}" || echo "https://${backend_url}")
frontend_url_full=$(echo "${frontend_url}" | grep -q "^https://" && echo "${frontend_url}" || echo "https://${frontend_url}")


  print_banner
  printf "${WHITE} 💻 Configurando variáveis de ambiente (backend)...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2

  # Verificar se o diretório existe
  if [ ! -d "/home/deploy/empresa/backend" ]; then
    printf "\n${RED} ⚠️ Diretório do backend não encontrado. Verifique se o repositório foi clonado corretamente.${GRAY_LIGHT}"
    printf "\n\n"
    sleep 5
    return 1
  fi

  sudo su - deploy << EOF
  # Verificar se já existe um arquivo .env e fazer backup
  if [ -f "/home/deploy/empresa/backend/.env" ]; then
    cp /home/deploy/empresa/backend/.env /home/deploy/empresa/backend/.env.backup
  fi
  
  cat <<[-]EOF > /home/deploy/empresa/backend/.env
NODE_ENV=production

BACKEND_URL=${backend_url_full}
BACKEND_PUBLIC_PATH=/home/deploy/empresa/backend/public
BACKEND_SESSION_PATH=/home/deploy/empresa/backend/metadados
FRONTEND_URL=${frontend_url_full}
PORT=${backend_port}
PROXY_PORT=443

DB_HOST=localhost
DB_DIALECT=postgres
DB_USER=empresa
DB_PASS=${mysql_root_password}
DB_NAME=empresa
DB_PORT=5432

TIMEOUT_TO_IMPORT_MESSAGE=999
FLUSH_REDIS_ON_START=false
DEBUG_TRACE=true
CHATBOT_RESTRICT_NUMBER=

REDIS_URI=redis://:${mysql_root_password}@127.0.0.1:${redis_port}
REDIS_HOST=127.0.0.1
REDIS_PORT=${redis_port}
REDIS_PASSWORD=${mysql_root_password}
REDIS_OPT_LIMITER_MAX=1
REDIS_OPT_LIMITER_DURATION=3000

USER_LIMIT=${max_user}
CONNECTIONS_LIMIT=${max_whats}

JWT_SECRET=${JWT_SECRET}
JWT_REFRESH_SECRET=${JWT_REFRESH_SECRET}
[-]EOF
EOF
  sleep 2
}

backend_node_dependencies() {
  print_banner
  printf "${WHITE} 💻 Instalando dependências do backend...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2

  # Verificar se o diretório existe
  if [ ! -d "/home/deploy/empresa/backend" ]; then
    printf "\n${RED} ⚠️ Diretório do backend não encontrado. Verifique se o repositório foi clonado corretamente.${GRAY_LIGHT}"
    printf "\n\n"
    sleep 5
    return 1
  fi

  # Criar diretórios necessários e definir permissões
  sudo mkdir -p /home/deploy/empresa/backend/logs
  sudo mkdir -p /home/deploy/empresa/backend/metadados
  sudo mkdir -p /home/deploy/empresa/backend/public/company1/medias
  sudo mkdir -p /home/deploy/empresa/backend/public/company1/tasks
  sudo mkdir -p /home/deploy/empresa/backend/public/company1/announcements
  sudo mkdir -p /home/deploy/empresa/backend/public/company1/logos
  sudo mkdir -p /home/deploy/empresa/backend/public/company1/backgrounds
  sudo mkdir -p /home/deploy/empresa/backend/public/company1/quickMessages
  sudo mkdir -p /home/deploy/empresa/backend/public/company1/profile
  
  # Ajustar permissões
  sudo chown -R deploy:deploy /home/deploy/empresa/
  
  # Instalar dependências
  sudo -u deploy bash -c "cd /home/deploy/empresa/backend && npm install"
  
  # Verificar resultado
  if [ $? -ne 0 ]; then
    printf "\n${RED} ⚠️ Erro ao instalar dependências do backend${GRAY_LIGHT}"
    
    # Tentar novamente com --force
    printf "\n${YELLOW} Tentando novamente com --force...${GRAY_LIGHT}"
    sudo -u deploy bash -c "cd /home/deploy/empresa/backend && npm install --force"
  fi

  # Ajustar permissões para o nginx
  sudo chown -R deploy:www-data /home/deploy/empresa/backend/public
  sudo chmod -R 775 /home/deploy/empresa/backend/public
  sudo usermod -a -G deploy www-data

  sleep 2
}

backend_node_build() {
  print_banner
  printf "${WHITE} 💻 Compilando o código do backend...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Verificar se o diretório node_modules existe
  if [ ! -d "/home/deploy/empresa/backend/node_modules" ]; then
    printf "\n${YELLOW} ⚠️ Diretório node_modules não encontrado. Executando npm install novamente...${GRAY_LIGHT}"
    sudo -u deploy bash -c "cd /home/deploy/empresa/backend && npm install"
  fi
  
  # Executar build
  sudo -u deploy bash -c "cd /home/deploy/empresa/backend && npm run build"
  
  # Verificar se o build foi concluído com sucesso
  if [ ! -d "/home/deploy/empresa/backend/dist" ]; then
    printf "\n${RED} ⚠️ Falha ao compilar o código do backend.${GRAY_LIGHT}"
    return 1
  fi
  
  # Copiar .env para dist
  sudo -u deploy bash -c "cd /home/deploy/empresa/backend && cp .env dist/"
  
  printf "\n${GREEN} ✅ Código do backend compilado com sucesso!${GRAY_LIGHT}"
  sleep 2
}

backend_db_migrate() {
  print_banner
  printf "${WHITE} 💻 Executando db:migrate...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Verificar se o PostgreSQL está rodando
  if ! sudo systemctl is-active --quiet postgresql; then
    printf "\n${RED} ⚠️ PostgreSQL não está rodando. Tentando iniciar...${GRAY_LIGHT}"
    sudo systemctl start postgresql
    sleep 3
  fi
  
  # Criar banco e usuário
  sudo su - postgres <<EOF
createdb empresa 2>/dev/null || echo "Banco 'empresa' já existe ou erro ao criar"
psql -c "CREATE USER empresa WITH ENCRYPTED PASSWORD '${mysql_root_password}' SUPERUSER INHERIT CREATEDB CREATEROLE;" 2>/dev/null || echo "Usuário 'empresa' já existe ou erro ao criar"
psql -c "ALTER DATABASE empresa OWNER TO empresa;" 2>/dev/null
EOF

  # Executar migrations
  sudo -u deploy bash -c "cd /home/deploy/empresa/backend && npx sequelize db:migrate"
  
  if [ $? -ne 0 ]; then
    printf "\n${RED} ⚠️ Erro ao executar migrations. Tentando instalar sequelize-cli e tentar novamente...${GRAY_LIGHT}"
    sudo -u deploy bash -c "cd /home/deploy/empresa/backend && npm install --save-dev sequelize-cli && npx sequelize db:migrate"
  fi
  
  printf "\n${GREEN} ✅ Migrations executadas!${GRAY_LIGHT}"
  sleep 2
}

backend_db_seed() {
  print_banner
  printf "${WHITE} 💻 Executando db:seed...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Executar seeds
  sudo -u deploy bash -c "cd /home/deploy/empresa/backend && npx sequelize db:seed:all"
  
  if [ $? -ne 0 ]; then
    printf "\n${RED} ⚠️ Erro ao executar seeds. Tentando novamente...${GRAY_LIGHT}"
    sudo -u deploy bash -c "cd /home/deploy/empresa/backend && npx sequelize db:seed:all --force"
  fi
  
  printf "\n${GREEN} ✅ Seeds executados!${GRAY_LIGHT}"
  sleep 2
}

backend_start_pm2() {
  print_banner
  printf "${WHITE} 💻 Iniciando pm2 (backend)...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Verificar se o PM2 está instalado globalmente
  if ! command -v pm2 &> /dev/null; then
    printf "\n${RED} ⚠️ PM2 não encontrado. Instalando...${GRAY_LIGHT}"
    sudo npm install -g pm2@latest
  fi
  
  # Configurar PM2 para o usuário deploy
  sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u deploy --hp /home/deploy || true
  
  # Criar arquivo de configuração PM2
  sudo -u deploy bash -c "cat > /home/deploy/empresa/backend/ecosystem.config.js << 'END'
module.exports = {
  apps: [{
    name: \"empresa-backend\",
    script: \"./dist/server.js\",
    node_args: \"--expose-gc --max-old-space-size=8192\",
    exec_mode: \"fork\",
    max_memory_restart: \"6G\",
    max_restarts: 5,
    instances: 1,
    watch: false,
    error_file: \"/home/deploy/empresa/backend/logs/error.log\",
    out_file: \"/home/deploy/empresa/backend/logs/out.log\",
    env: {
      NODE_ENV: \"production\"
    }
  }]
}
END"

  # Parar aplicação anterior, se existir
  sudo -u deploy bash -c "cd /home/deploy/empresa/backend && pm2 delete empresa-backend 2>/dev/null || true"
  
  # Iniciar aplicação e salvar configuração
  sudo -u deploy bash -c "cd /home/deploy/empresa/backend && pm2 start ecosystem.config.js && pm2 save"
  
  # Verificar se o processo foi iniciado corretamente
  if sudo -u deploy bash -c "pm2 list | grep -q empresa-backend"; then
    printf "\n${GREEN} ✅ Backend iniciado com PM2 com sucesso!${GRAY_LIGHT}"
  else
    printf "\n${RED} ⚠️ Erro ao iniciar o backend com PM2. Verifique os logs.${GRAY_LIGHT}"
  fi
  
  sleep 2
}

backend_nginx_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando nginx (backend)...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2

  backend_hostname=$(echo "${backend_url}" | sed 's~^https://~~')
  
  sudo bash -c "cat > /etc/nginx/sites-available/empresa-backend << EOF
server {
  server_name ${backend_hostname};
  
  location / {
    proxy_pass http://127.0.0.1:${backend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \\\$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \\\$host;
    proxy_set_header X-Real-IP \\\$remote_addr;
    proxy_set_header X-Forwarded-Proto \\\$scheme;
    proxy_set_header X-Forwarded-For \\\$proxy_add_x_forwarded_for;
    proxy_cache_bypass \\\$http_upgrade;
  }

  # Bloquear solicitações de arquivos do GitHub
  location ~ /\\.git {
    deny all;
  }
}
EOF"

  sudo ln -sf /etc/nginx/sites-available/empresa-backend /etc/nginx/sites-enabled/
  sleep 2
}