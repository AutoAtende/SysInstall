#!/bin/bash

backend_redis_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando Redis para o backend...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Verificando se o Redis está rodando
  sudo systemctl status redis-server --no-pager
  
  sleep 2
}

backend_set_env() {
  print_banner
  printf "${WHITE} 💻 Configurando variáveis de ambiente (backend)...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Tratamento das URLs
  backend_url=$(echo "${backend_url/https:\/\/}")
  backend_url=${backend_url%%/*}
  backend_url=https://$backend_url
  
  frontend_url=$(echo "${frontend_url/https:\/\/}")
  frontend_url=${frontend_url%%/*}
  frontend_url=https://$frontend_url
  
  # Gerar URLs WSS e WS baseadas no backend_url
  backend_host=$(echo "${backend_url/https:\/\/}")
  backend_wss="wss://${backend_host}"
  backend_ws="ws://${backend_host}"
  
  # Gerar URL WSS do frontend
  frontend_host=$(echo "${frontend_url/https:\/\/}")
  frontend_wss="wss://${frontend_host}"
  
  # Gerar secrets
  JWT_SECRET=$(openssl rand -hex 32)
  JWT_REFRESH_SECRET=$(openssl rand -hex 32)

sudo su - deploy << EOF
  cat <<[-]EOF > /home/deploy/${instancia_add}/backend/.env
NODE_ENV=production

# URLs Base
BACKEND_URL=${backend_url}
FRONTEND_URL=${frontend_url}

# URLs WebSocket
BACKEND_WSS=${backend_wss}
BACKEND_WS=${backend_ws}
FRONTEND_WSS=${frontend_wss}
PROXY_PORT=443

# Porta da aplicação
PORT=${backend_port}

# Configurações do Banco de Dados
DB_HOST=localhost
DB_DIALECT=postgres
DB_USER=${instancia_add}
DB_PASS=${mysql_root_password}
DB_NAME=${instancia_add}
DB_PORT=5432

# Configurações especificas do AutoAtende
TIMEOUT_TO_IMPORT_MESSAGE=999
FLUSH_REDIS_ON_START=false
DEBUG_TRACE=false
CHATBOT_RESTRICT_NUMBER=

# Configurações do Redis
REDIS_URI=redis://:${mysql_root_password}@127.0.0.1:${redis_port}
REDIS_HOST=127.0.0.1
REDIS_PORT=${redis_port}
REDIS_PASSWORD=${mysql_root_password}
REDIS_OPT_LIMITER_MAX=1
REDIS_OPT_LIMITER_DURATION=3000

# Limites do sistema
USER_LIMIT=${max_user}
CONNECTIONS_LIMIT=${max_whats}

# Secrets
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

sudo su - deploy <<EOF
cd /home/deploy/${instancia_add}/backend
mkdir logs
chmod 777 logs
mkdir public
chmod 777 public
mkdir -p public/company1
chmod 777 public/company1
mkdir -p public/company1/medias
chmod 777 public/company1/medias
mkdir -p public/company1/tasks
chmod 777 public/company1/tasks
mkdir -p public/company1/announcements
chmod 777 public/company1/announcements
mkdir -p public/company1/logos
chmod 777 public/company1/logos
mkdir -p public/company1/backgrounds
chmod 777 public/company1/backgrounds
mkdir -p public/company1/quickMessages
chmod 777 public/company1/quickMessages
mkdir -p public/company1/profile
chmod 777 public/company1/profile
npm install
EOF

  # Ajustando permissões para o nginx acessar os arquivos
  sudo su - root <<EOF
  chown -R deploy:www-data /home/deploy/${instancia_add}/backend/public
  chmod -R 775 /home/deploy/${instancia_add}/backend/public
  usermod -a -G deploy www-data
EOF

  sleep 2
}

backend_node_build() {
  print_banner
  printf "${WHITE} 💻 Compilando o código do backend...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
sudo su - deploy <<EOF
cd /home/deploy/${instancia_add}/backend
npm run build
cp .env dist/
rm -rf src
EOF
  sleep 2
}

backend_db_migrate() {
  print_banner
  printf "${WHITE} 💻 Executando db:migrate...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Criando banco e usuário
  sudo su - postgres <<EOF
createdb ${instancia_add}
psql -c "CREATE USER ${instancia_add} WITH ENCRYPTED PASSWORD '${mysql_root_password}' SUPERUSER INHERIT CREATEDB CREATEROLE;"
psql -c "ALTER DATABASE ${instancia_add} OWNER TO ${instancia_add};"
EOF

  # Executando migrations
  sudo su - deploy <<EOF
cd /home/deploy/${instancia_add}/backend
npx sequelize db:migrate
EOF
  sleep 2
}

backend_db_seed() {
  print_banner
  printf "${WHITE} 💻 Executando db:seed...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
sudo su - deploy <<EOF
cd /home/deploy/${instancia_add}/backend
npx sequelize db:seed:all
EOF
  sleep 2
}

backend_start_pm2() {
  print_banner
  printf "${WHITE} 💻 Iniciando pm2 (backend)...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  sudo su - deploy << EOF
  cat > /home/deploy/${instancia_add}/backend/ecosystem.config.js << 'END'
module.exports = {
  apps: [{
    name: "${instancia_add}-backend",
    script: "./dist/server.js",
    node_args: "--expose-gc --max-old-space-size=8192",
    exec_mode: "fork",
    max_memory_restart: "6G",
    max_restarts: 5,
    instances: 1,
    watch: false,
    error_file: "/home/deploy/${instancia_add}/backend/logs/error.log",
    out_file: "/home/deploy/${instancia_add}/backend/logs/out.log",
    env: {
      NODE_ENV: "production"
    }
  }]
}
END
cd /home/deploy/${instancia_add}/backend
pm2 start ecosystem.config.js
pm2 save
EOF
  sleep 2
}

backend_nginx_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando nginx (backend)...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  backend_hostname=$(echo "${backend_url/https:\/\/}")

sudo su - root << EOF
cat > /etc/nginx/sites-available/${instancia_add}-backend << 'END'
server {
  server_name $backend_hostname;

  # Configurações de segurança gerais
  add_header X-Frame-Options "SAMEORIGIN" always;
  add_header X-XSS-Protection "1; mode=block" always;
  add_header X-Content-Type-Options "nosniff" always;
  add_header Referrer-Policy "strict-origin-when-cross-origin" always;
  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

  # Configuração principal
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

    # Headers CORS
    add_header 'Access-Control-Allow-Origin' '$frontend_url' always;
    add_header 'Access-Control-Allow-Credentials' 'true' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization' always;

    # Tratamento especial para OPTIONS
    if (\$request_method = 'OPTIONS') {
      add_header 'Access-Control-Allow-Origin' '$frontend_url' always;
      add_header 'Access-Control-Allow-Credentials' 'true' always;
      add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
      add_header 'Access-Control-Allow-Headers' 'DNT,X-CustomHeader,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization' always;
      add_header 'Access-Control-Max-Age' 1728000;
      add_header 'Content-Type' 'text/plain charset=UTF-8';
      add_header 'Content-Length' 0;
      return 204;
    }
  }

  # Configuração específica para WebSocket
  location /socket.io/ {
    proxy_pass http://127.0.0.1:${backend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
    proxy_buffering off;
    
    # Headers CORS para WebSocket
    add_header 'Access-Control-Allow-Origin' '$frontend_url' always;
    add_header 'Access-Control-Allow-Credentials' 'true' always;
  }

  # Bloqueio de arquivos sensíveis
  location ~ /\.(git|env|config|docker) {
    deny all;
    return 404;
  }

  # Limitar tamanho de upload
  client_max_body_size 50M;
}
END
ln -s /etc/nginx/sites-available/${instancia_add}-backend /etc/nginx/sites-enabled
EOF
  sleep 2
}

