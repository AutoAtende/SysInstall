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

sudo su - deploy << EOF
  cat <<[-]EOF > /home/deploy/empresa/backend/.env
NODE_ENV=production

BACKEND_URL=${backend_url}
BACKEND_PUBLIC_PATH=/home/deploy/empresa/backend/public
BACKEND_SESSION_PATH=/home/deploy/empresa/backend/metadados
FRONTEND_URL=${frontend_url}
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

sudo su - deploy <<EOF
cd /home/deploy/empresa/backend
mkdir logs
chmod 775 logs
mkdir metadados
chmod 775 metadados
mkdir public
chmod 775 public
mkdir -p public/company1
chmod 775 public/company1
mkdir -p public/company1/medias
chmod 775 public/company1/medias
mkdir -p public/company1/tasks
chmod 775 public/company1/tasks
mkdir -p public/company1/announcements
chmod 775 public/company1/announcements
mkdir -p public/company1/logos
chmod 775 public/company1/logos
mkdir -p public/company1/backgrounds
chmod 775 public/company1/backgrounds
mkdir -p public/company1/quickMessages
chmod 775 public/company1/quickMessages
mkdir -p public/company1/profile
chmod 775 public/company1/profile
npm install
EOF

  # Ajustando permissões para o nginx acessar os arquivos
  sudo su - root <<EOF
  chown -R deploy:www-data /home/deploy/empresa/backend/public
  chmod -R 775 /home/deploy/empresa/backend/public
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
cd /home/deploy/empresa/backend
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
createdb empresa
psql -c "CREATE USER empresa WITH ENCRYPTED PASSWORD '${mysql_root_password}' SUPERUSER INHERIT CREATEDB CREATEROLE;"
psql -c "ALTER DATABASE empresa OWNER TO empresa;"
EOF

  # Executando migrations
  sudo su - deploy <<EOF
cd /home/deploy/empresa/backend
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
cd /home/deploy/empresa/backend
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
  cat > /home/deploy/empresa/backend/ecosystem.config.js << 'END'
module.exports = {
  apps: [{
    name: "empresa-backend",
    script: "./dist/server.js",
    node_args: "--expose-gc --max-old-space-size=8192",
    exec_mode: "fork",
    max_memory_restart: "6G",
    max_restarts: 5,
    instances: 1,
    watch: false,
    error_file: "/home/deploy/empresa/backend/logs/error.log",
    out_file: "/home/deploy/empresa/backend/logs/out.log",
    env: {
      NODE_ENV: "production"
    }
  }]
}
END
cd /home/deploy/empresa/backend
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
cat > /etc/nginx/sites-available/empresa-backend << 'END'
server {
  server_name $backend_hostname;
  
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
  location ~ /\.git {
    deny all;
  }
}
END
ln -s /etc/nginx/sites-available/empresa-backend /etc/nginx/sites-enabled
EOF
  sleep 2
}