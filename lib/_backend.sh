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
  
  # Testar conexão com Redis usando a senha definida
  printf "\n${WHITE} 🔄 Testando conexão com Redis...${GRAY_LIGHT}\n"
  
  # Testar como usuário root
  if redis-cli -a "${mysql_root_password}" ping | grep -q "PONG"; then
    printf "${GREEN} ✅ Conexão Redis bem sucedida como root!${GRAY_LIGHT}\n"
  else
    printf "${RED} ⚠️ Falha na conexão Redis como root.${GRAY_LIGHT}\n"
  fi
  
  # Testar como usuário deploy
  if sudo -u deploy bash -c "redis-cli -a \"${mysql_root_password}\" ping" | grep -q "PONG"; then
    printf "${GREEN} ✅ Conexão Redis bem sucedida como usuário deploy!${GRAY_LIGHT}\n"
  else
    printf "${RED} ⚠️ Falha na conexão Redis como usuário deploy. Ajustando permissões...${GRAY_LIGHT}\n"
    sudo usermod -a -G redis deploy 2>/dev/null || true
    sudo systemctl restart redis-server
    sleep 2
    
    if sudo -u deploy bash -c "redis-cli -a \"${mysql_root_password}\" ping" | grep -q "PONG"; then
      printf "${GREEN} ✅ Conexão Redis bem sucedida após ajustes!${GRAY_LIGHT}\n"
    else
      printf "${RED} ⚠️ Problemas persistem. Verifique a configuração manualmente.${GRAY_LIGHT}\n"
    fi
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
  
  # Ajustar permissões adequadamente
  sudo chown -R deploy:deploy /home/deploy/empresa/
  
  # Verificar se Node.js está configurado para o usuário deploy
  printf "\n${WHITE} 🔄 Verificando Node.js para o usuário deploy...${GRAY_LIGHT}\n"
  node_version=$(sudo -u deploy bash -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; node -v')
  
  if [[ -z "$node_version" ]]; then
    printf "${RED} ⚠️ Node.js não encontrado para o usuário deploy. Reinstalando NVM...${GRAY_LIGHT}\n"
    
    # Reinstalar NVM para o usuário deploy
    sudo su - deploy << EOF
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    export NVM_DIR="\$HOME/.nvm"
    [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
    nvm install 20.18.0
    nvm use 20.18.0
    nvm alias default 20.18.0
EOF
  fi
  
  # Instalar dependências com o NVM do usuário deploy
  printf "\n${WHITE} 🔄 Instalando dependências com npm...${GRAY_LIGHT}\n"
  sudo -u deploy bash -c "cd /home/deploy/empresa/backend && export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\" && npm install"
  
  # Verificar resultado
  if [ $? -ne 0 ]; then
    printf "\n${RED} ⚠️ Erro ao instalar dependências do backend${GRAY_LIGHT}"
    
    # Tentar novamente com --force
    printf "\n${YELLOW} Tentando novamente com --force...${GRAY_LIGHT}"
    sudo -u deploy bash -c "cd /home/deploy/empresa/backend && export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\" && npm install --force"
  fi

  # Ajustar permissões para o nginx e usuário deploy
  sudo chown -R deploy:www-data /home/deploy/empresa/backend/public
  sudo chmod -R 775 /home/deploy/empresa/backend/public
  
  # Garantir que www-data esteja no grupo deploy
  sudo usermod -a -G deploy www-data
  
  # Garantir que novos arquivos herdem as permissões do grupo
  sudo find /home/deploy/empresa/backend/public -type d -exec chmod g+s {} \;

  printf "\n${GREEN} ✅ Dependências instaladas e permissões configuradas!${GRAY_LIGHT}"
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
  
  # Verificar NVM e Node.js para o usuário deploy
  node_version=$(sudo -u deploy bash -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; node -v')
  if [[ -z "$node_version" ]]; then
    printf "\n${RED} ⚠️ Node.js não está configurado para o usuário deploy. Isso precisa ser corrigido antes de continuar.${GRAY_LIGHT}"
    return 1
  fi
  
  # Criar arquivo de configuração PM2 para o usuário deploy
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
  sudo -u deploy bash -c "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\" && cd /home/deploy/empresa/backend && pm2 delete empresa-backend 2>/dev/null || true"
  
  # Iniciar aplicação com PM2 usando o NVM do usuário deploy
  sudo -u deploy bash -c "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\" && cd /home/deploy/empresa/backend && pm2 start ecosystem.config.js && pm2 save"
  
  # Verificar se o processo foi iniciado corretamente
  if sudo -u deploy bash -c "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\" && pm2 list | grep -q empresa-backend"; then
    printf "\n${GREEN} ✅ Backend iniciado com PM2 com sucesso!${GRAY_LIGHT}"
    
    # Configurar PM2 para iniciar automaticamente
    sudo env PATH=$PATH:/usr/bin /home/deploy/.npm-global/bin/pm2 startup systemd -u deploy --hp /home/deploy
    sudo -u deploy bash -c "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\" && pm2 save"
  else
    printf "\n${RED} ⚠️ Erro ao iniciar o backend com PM2. Verificando logs...${GRAY_LIGHT}"
    sudo -u deploy bash -c "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\" && pm2 logs --lines 20"
  fi
  
  sleep 2
}

backend_nginx_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando nginx (backend)...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2

  backend_hostname=$(echo "${backend_url}" | sed 's~^https://~~' | sed 's~/.*$~~')
  
  sudo bash -c "cat > /etc/nginx/sites-available/empresa-backend << 'EOF'
server {
  server_name ${backend_hostname};
  
  location / {
    proxy_pass http://127.0.0.1:${backend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
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