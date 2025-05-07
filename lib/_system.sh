#!/bin/bash

system_update() {
  print_banner
  printf "${WHITE} 💻 Vamos preparar o sistema para o AutoAtende...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  sudo su - root <<EOF
  sudo apt -y update
  sudo apt-get -y upgrade
  sudo apt-get install -y build-essential libxshmfence-dev libgbm-dev wget unzip fontconfig locales gconf-service libasound2 libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 libnspr4 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 ca-certificates fonts-liberation libappindicator1 libnss3 lsb-release xdg-utils
  sudo apt-get autoremove -y
EOF
  sleep 2
}

system_node_install() {
  print_banner
  printf "${WHITE} 💻 Verificando Node.js...${GRAY_LIGHT}"
  printf "\n\n"
  
  # Verificar se o Node.js já está configurado para o usuário deploy
  node_version=""
  
  if id "deploy" &>/dev/null; then
    # Verificar se existe via NVM
    node_version=$(sudo -u deploy bash -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; node -v 2>/dev/null || echo ""')
    
    # Se não encontrou via NVM, verificar instalação direta
    if [ -z "$node_version" ]; then
      node_version=$(sudo -u deploy bash -c 'command -v node &> /dev/null && node -v' 2>/dev/null || echo "")
    fi
  fi
  
  if [ ! -z "$node_version" ] && [ "$use_existing_components" = "true" ]; then
    printf "${GREEN} ✅ Node.js ${node_version} já está instalado para o usuário deploy${GRAY_LIGHT}\n"
    
    # Verificar compatibilidade (se estamos próximos da versão desejada)
    if [[ "$node_version" =~ ^v20 ]]; then
      printf "${GREEN} ✅ Versão compatível do Node.js detectada${GRAY_LIGHT}\n"
    else
      printf "${YELLOW} ⚠️ A versão do Node.js (${node_version}) pode não ser totalmente compatível.${GRAY_LIGHT}\n"
      printf "${YELLOW} Recomendado: Node.js v20.x. Continuar mesmo assim? (y/N)${GRAY_LIGHT} "
      read -n 1 -r
      printf "\n"
      
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf "${YELLOW} Instalando Node.js 20 via NVM...${GRAY_LIGHT}\n"
        
        # Configurar NVM para o usuário deploy e instalar Node.js 20
        sudo -u deploy bash -c '
          export NVM_DIR="$HOME/.nvm"
          [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
          
          # Verificar se NVM está instalado, caso contrário instalar
          if ! command -v nvm &> /dev/null; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
          fi
          
          # Instalar Node.js 20
          nvm install 20
          nvm use 20
          nvm alias default 20
        '
      fi
    fi
  else
    printf "${YELLOW} ⚠️ Node.js não detectado ou reinstalação solicitada. Instalando...${GRAY_LIGHT}\n"
    
    # Instalar PostgreSQL 16 (MANTENDO ESTA PARTE CRUCIAL)
    if ! command -v psql &> /dev/null || [ "$postgresql_installed" != "true" ]; then
      printf "\n${WHITE} 💻 Instalando PostgreSQL 16...${GRAY_LIGHT}"
      sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
      wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
      sudo apt-get update -y
      sudo apt-get -y install postgresql-16
      
      sudo systemctl enable postgresql
      sudo systemctl start postgresql
    else
      printf "\n${GREEN} ✅ PostgreSQL já está instalado${GRAY_LIGHT}\n"
    fi
    
    # Configurar fuso horário
    sudo timedatectl set-timezone America/Sao_Paulo
    
    # Instalar NVM para o usuário deploy
    sudo su - deploy << EOF
    # Remover instalação anterior do NVM, se existir
    rm -rf ~/.nvm
    
    # Remover arquivo .npmrc se existir para evitar conflitos
    rm -f ~/.npmrc
    
    # Baixar e instalar NVM usando wget
    wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    # Configurar NVM no perfil do usuário
    export NVM_DIR="\$HOME/.nvm"
    [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
    
    # Instalar Node.js 20 especificamente
    nvm install 20
    nvm use 20 --delete-prefix
    nvm alias default 20
    
    # Verificar a instalação
    node -v
    npm -v
    
    # Adicionar configuração aos arquivos de perfil
    echo 'export NVM_DIR="\$HOME/.nvm"' >> \$HOME/.bashrc
    echo '[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"' >> \$HOME/.bashrc
    echo 'export NVM_DIR="\$HOME/.nvm"' >> \$HOME/.profile
    echo '[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"' >> \$HOME/.profile
EOF
  fi
  
  printf "\n${GREEN} ✅ Verificação e configuração do Node.js concluída!${GRAY_LIGHT}\n"
  sleep 2
}

system_redis_install() {
  print_banner
  printf "${WHITE} 💻 Verificando Redis...${GRAY_LIGHT}"
  printf "\n\n"
  
  # Verificar se o Redis já está instalado e funcionando
  redis_running=false
  if command -v redis-cli &> /dev/null && sudo systemctl is-active --quiet redis-server; then
    redis_running=true
    redis_version=$(redis-server --version | grep -o 'v=[0-9.]*' | cut -d= -f2)
    printf "${GREEN} ✅ Redis versão ${redis_version} já está instalado e rodando${GRAY_LIGHT}\n"
  fi
  
  if [ "$redis_running" = "true" ] && [ "$use_existing_components" = "true" ]; then
    printf "${GREEN} ✅ Usando instalação existente do Redis${GRAY_LIGHT}\n"
    
    # Verificar se precisamos atualizar a configuração
    printf "${YELLOW} ⚠️ Deseja atualizar a configuração do Redis para o AutoAtende? (y/N)${GRAY_LIGHT} "
    read -n 1 -r
    printf "\n"
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      # Fazer backup da configuração atual
      sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.bak.$(date +%Y%m%d%H%M%S)
      
      # Atualizar configuração
      sudo bash -c "cat > /etc/redis/redis.conf << EOF
# Redis configuração para AutoAtende
bind 127.0.0.1
port ${redis_port}
protected-mode yes
requirepass ${mysql_root_password}
maxmemory 2gb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
no-appendfsync-on-rewrite yes
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes
# Melhorias de performance
activedefrag yes
maxclients 10000
timeout 300
tcp-keepalive 300
EOF"
      
      # Reiniciar Redis
      sudo systemctl restart redis-server
      printf "${GREEN} ✅ Configuração do Redis atualizada${GRAY_LIGHT}\n"
      
      # Testar conexão
      if redis-cli -a "${mysql_root_password}" ping | grep -q "PONG"; then
        printf "${GREEN} ✅ Teste de conexão Redis bem sucedido!${GRAY_LIGHT}\n"
      else
        printf "${RED} ⚠️ Teste de conexão Redis falhou. Restaurando configuração...${GRAY_LIGHT}\n"
        sudo cp /etc/redis/redis.conf.bak.$(ls -t /etc/redis/redis.conf.bak.* | head -n1 | cut -d. -f3) /etc/redis/redis.conf
        sudo systemctl restart redis-server
      fi
    else
      printf "${YELLOW} ⚠️ Mantendo configuração atual do Redis${GRAY_LIGHT}\n"
      
      # Verificar se podemos testar a senha atual
      printf "${YELLOW} ⚠️ Por favor, informe a senha atual do Redis (deixe em branco para tentar sem senha):${GRAY_LIGHT} "
      read -s current_redis_password
      printf "\n"
      
      if [ -z "$current_redis_password" ]; then
        if redis-cli ping | grep -q "PONG"; then
          printf "${GREEN} ✅ Redis está acessível sem senha${GRAY_LIGHT}\n"
        else
          printf "${RED} ⚠️ Não foi possível conectar ao Redis sem senha${GRAY_LIGHT}\n"
          printf "${YELLOW} ⚠️ Você precisará configurar a senha manualmente no arquivo .env mais tarde${GRAY_LIGHT}\n"
        fi
      else
        if redis-cli -a "$current_redis_password" ping | grep -q "PONG"; then
          printf "${GREEN} ✅ Redis está acessível com a senha fornecida${GRAY_LIGHT}\n"
          mysql_root_password="$current_redis_password"
          printf "${GREEN} ✅ Usando a senha do Redis existente para configuração${GRAY_LIGHT}\n"
        else
          printf "${RED} ⚠️ Não foi possível conectar ao Redis com a senha fornecida${GRAY_LIGHT}\n"
          printf "${YELLOW} ⚠️ Você precisará configurar a senha manualmente no arquivo .env mais tarde${GRAY_LIGHT}\n"
        fi
      fi
    fi
  else
    printf "${YELLOW} ⚠️ Redis não detectado ou reinstalação solicitada. Instalando...${GRAY_LIGHT}\n"
    
    # Código original para instalar o Redis
    # Remover instalações anteriores
    sudo apt-get remove --purge -y redis-server redis-tools || true
    sudo apt-get autoremove -y
    sudo rm -rf /etc/redis /var/lib/redis
    
    # Adicionar repositório do Redis 7.x
    sudo su - root <<EOF
    # Remover chave antiga se existir
    rm -f /usr/share/keyrings/redis-archive-keyring.gpg
    
    # Adicionar repositório do Redis com tratamento adequado para evitar prompts
    curl -fsSL https://packages.redis.io/gpg | gpg --yes --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb \$(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list > /dev/null
    
    # Atualizar e instalar Redis
    apt-get update -y
    apt-get install -y redis-server
EOF
    
    # Continuar com a configuração original...
    # Fazer backup da configuração original do Redis
    sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.backup
    
    # Configurar Redis
    sudo bash -c "cat > /etc/redis/redis.conf << EOF
# Redis 7.x configuração
bind 127.0.0.1
port ${redis_port}
protected-mode yes
requirepass ${mysql_root_password}
maxmemory 2gb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
no-appendfsync-on-rewrite yes
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes
# Melhorias de performance
activedefrag yes
maxclients 10000
timeout 300
tcp-keepalive 300
EOF"
    
    # Reiniciar Redis e configurar para iniciar com o sistema
    sudo systemctl restart redis-server
    sudo systemctl enable redis-server
  fi
  
  # Garantir que o usuário deploy tenha acesso ao Redis
  sudo usermod -a -G redis deploy 2>/dev/null || true
  
  printf "\n${GREEN} ✅ Verificação e configuração do Redis concluída!${GRAY_LIGHT}\n"
  sleep 2
}

system_create_user() {
  print_banner
  printf "${WHITE} 💻 Verificando usuário deploy...${GRAY_LIGHT}"
  printf "\n\n"

  if id "deploy" &>/dev/null && [ "$use_existing_components" = "true" ]; then
    printf "${GREEN} ✅ Usuário deploy já existe e será mantido${GRAY_LIGHT}\n"
    
    # Garantir que o usuário deploy esteja nos grupos corretos
    sudo usermod -aG sudo deploy 2>/dev/null || true
    
    # Verificar permissões do diretório home
    if [ -d "/home/deploy" ]; then
      sudo chmod 755 /home/deploy
      printf "${GREEN} ✅ Permissões do diretório /home/deploy verificadas${GRAY_LIGHT}\n"
    else
      printf "${RED} ⚠️ Diretório /home/deploy não encontrado, mas usuário existe!${GRAY_LIGHT}\n"
      printf "${YELLOW} Criando diretório home...${GRAY_LIGHT}\n"
      sudo mkdir -p /home/deploy
      sudo chown deploy:deploy /home/deploy
      sudo chmod 755 /home/deploy
    fi
  else
    # Código original para criar o usuário
    printf "${WHITE} 🔄 Criando novo usuário deploy...${GRAY_LIGHT}\n"
    
    # Remover usuário e grupo se existirem
    sudo userdel -rf deploy >/dev/null 2>&1 || true
    sudo groupdel deploy >/dev/null 2>&1 || true
    sudo rm -rf /home/deploy >/dev/null 2>&1 || true
    
    # Criar grupo deploy
    sudo groupadd deploy
    
    # Criar usuário deploy com senha definida diretamente
    sudo useradd -m -s /bin/bash -g deploy deploy
    
    # Definir senha
    echo "deploy:${mysql_root_password}" | sudo chpasswd
    
    # Adicionar ao grupo sudo
    sudo usermod -aG sudo deploy
    
    # Ajustar permissões do diretório home
    if [ -d "/home/deploy" ]; then
      sudo chown -R deploy:deploy /home/deploy
      sudo chmod 755 /home/deploy
    else
      printf "\n${RED} ⚠️ Erro: Diretório /home/deploy não foi criado!${GRAY_LIGHT}\n"
      exit 1
    fi
  fi

  printf "\n${GREEN} ✅ Verificação do usuário deploy concluída!${GRAY_LIGHT}\n"
  sleep 2
}

system_generate_jwt_secrets() {
  if [ -z "$JWT_SECRET" ]; then
    JWT_SECRET=$(openssl rand -hex 32)
  fi
  
  if [ -z "$JWT_REFRESH_SECRET" ]; then
    JWT_REFRESH_SECRET=$(openssl rand -hex 32)
  fi
}

system_git_clone() {
  print_banner
  printf "${WHITE} 💻 Clonando repositório...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Verificar se o token foi definido
  if [ -z "$token_code" ]; then
    printf "\n${RED} ⚠️ Token não definido. Não é possível clonar o repositório.${GRAY_LIGHT}"
    printf "\n\n"
    sleep 5
    return 1
  fi
  
  # Limpar qualquer instalação anterior
  sudo rm -rf /home/deploy/empresa
  
  # Criar diretório base
  sudo mkdir -p /home/deploy/empresa
  sudo chown -R deploy:deploy /home/deploy/empresa
  
  # Tentar clonar o repositório
  if sudo -u deploy git clone https://lucassaud:${token_code}@github.com/AutoAtende/Sys3.git /home/deploy/empresa/ ; then
    printf "\n${GREEN} ✅ Repositório clonado com sucesso!${GRAY_LIGHT}"
  else
    printf "\n${RED} ⚠️ Falha ao clonar o repositório. Verificando conectividade...${GRAY_LIGHT}"
    
    # Verificar conectividade
    if ping -c 1 github.com &> /dev/null; then
      printf "\n${YELLOW} Conexão com github.com está funcionando. Problema pode ser com o token.${GRAY_LIGHT}"
    else
      printf "\n${RED} Sem conectividade com github.com. Verifique sua conexão.${GRAY_LIGHT}"
    fi
    
    sleep 5
    return 1
  fi
  
  # Garantir permissões corretas
  sudo chown -R deploy:deploy /home/deploy/empresa
  
  sleep 2
}

system_pm2_install() {
  print_banner
  printf "${WHITE} 💻 Verificando PM2...${GRAY_LIGHT}\n\n"
  
  # Verificar se o PM2 já está instalado
  pm2_installed=false
  if id "deploy" &>/dev/null; then
    pm2_version=$(sudo -u deploy bash -c "export NVM_DIR=\"\$HOME/.nvm\"; [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"; pm2 --version 2>/dev/null || echo \"\"")
    
    if [ ! -z "$pm2_version" ]; then
      pm2_installed=true
      printf "${GREEN} ✅ PM2 versão ${pm2_version} já está instalado para o usuário deploy${GRAY_LIGHT}\n"
    fi
  fi
  
  if [ "$pm2_installed" = "true" ] && [ "$use_existing_components" = "true" ]; then
    printf "${GREEN} ✅ Usando instalação existente do PM2${GRAY_LIGHT}\n"
    
    # Verificar configuração do startup
    printf "${YELLOW} ⚠️ Deseja configurar o PM2 para iniciar automaticamente? (y/N)${GRAY_LIGHT} "
    read -n 1 -r
    printf "\n"
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      # Configurar PM2 startup
      sudo env PATH=$PATH:/usr/bin /home/deploy/.nvm/versions/node/*/bin/pm2 startup systemd -u deploy --hp /home/deploy || true
      
      printf "${GREEN} ✅ PM2 configurado para iniciar automaticamente${GRAY_LIGHT}\n"
    fi
  else
    printf "${YELLOW} ⚠️ PM2 não detectado ou reinstalação solicitada. Instalando...${GRAY_LIGHT}\n"
    
    # Código original para instalar o PM2
    # Remover .npmrc se existir para evitar conflitos com NVM
    sudo -u deploy bash -c "rm -f ~/.npmrc"
    
    # Instalar PM2 globalmente para o usuário deploy usando NVM
    sudo su - deploy << EOF
    # Remover qualquer configuração que possa causar conflito
    rm -f ~/.npmrc
    
    # Carregar NVM
    export NVM_DIR="\$HOME/.nvm"
    [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
    
    # Usar node com a opção delete-prefix para resolver conflitos
    nvm use 20 --delete-prefix
    
    # Verificar se o Node.js está disponível
    if command -v node &> /dev/null; then
      echo "Node.js encontrado: \$(node -v)"
    else
      echo "Node.js não encontrado, tentando carregar novamente NVM"
      source ~/.nvm/nvm.sh
      nvm use 20 --delete-prefix
    fi
    
    # Instalar PM2 globalmente
    echo "Instalando PM2..."
    npm install -g pm2@latest
    
    # Verificar a instalação
    echo "Versão do PM2 instalada:"
    pm2 --version
EOF

    # Verificar se o PM2 foi instalado
    pm2_version=$(sudo -u deploy bash -c "export NVM_DIR=\"\$HOME/.nvm\"; [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"; pm2 --version 2>/dev/null || echo \"\"")
  fi
  
  printf "\n${GREEN} ✅ Verificação e configuração do PM2 concluída!${GRAY_LIGHT}\n"
  sleep 2
}

system_verify_environment() {
  print_banner
  printf "${WHITE} 🔍 Verificando ambiente para o usuário deploy...${GRAY_LIGHT}\n\n"
  
  # Verificar PostgreSQL
  if sudo systemctl is-active --quiet postgresql; then
    printf "${GREEN} ✅ PostgreSQL está ativo e funcionando${GRAY_LIGHT}\n"
  else
    printf "${RED} ❌ PostgreSQL não está ativo! Tentando iniciar...${GRAY_LIGHT}\n"
    sudo systemctl start postgresql
    sleep 2
    if ! sudo systemctl is-active --quiet postgresql; then
      printf "${RED} ❌ Falha ao iniciar PostgreSQL${GRAY_LIGHT}\n"
      return 1
    fi
  fi
  
  # Verificar e corrigir conflitos de .npmrc para o usuário deploy
  printf "${WHITE} 🔍 Verificando configuração do npm...${GRAY_LIGHT}\n"
  if sudo -u deploy test -f /home/deploy/.npmrc; then
    printf "${YELLOW} ⚠️ Arquivo .npmrc encontrado. Removendo para evitar conflitos com NVM.${GRAY_LIGHT}\n"
    sudo -u deploy bash -c "rm -f ~/.npmrc"
  fi
  
  # Verificar Node.js
  node_version=$(sudo -u deploy bash -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; nvm use 20 --delete-prefix --silent 2>/dev/null; node -v 2>/dev/null || echo ""')
  
  if [[ -z "$node_version" ]]; then
    printf "${RED} ❌ Node.js não está instalado para o usuário deploy${GRAY_LIGHT}\n"
    return 1
  else
    printf "${GREEN} ✅ Node.js ${node_version} instalado para o usuário deploy${GRAY_LIGHT}\n"
  fi
  
  # Verificar NPM
  npm_version=$(sudo -u deploy bash -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; nvm use 20 --delete-prefix --silent 2>/dev/null; npm -v 2>/dev/null || echo ""')
  
  if [[ -z "$npm_version" ]]; then
    printf "${RED} ❌ NPM não está instalado para o usuário deploy${GRAY_LIGHT}\n"
    return 1
  else
    printf "${GREEN} ✅ NPM ${npm_version} instalado para o usuário deploy${GRAY_LIGHT}\n"
  fi
  
  # Verificar PM2
  pm2_version=$(sudo -u deploy bash -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; nvm use 20 --delete-prefix --silent 2>/dev/null; pm2 --version 2>/dev/null || echo ""')
  
  if [[ -z "$pm2_version" ]]; then
    printf "${RED} ❌ PM2 não está instalado para o usuário deploy${GRAY_LIGHT}\n"
    return 1
  else
    printf "${GREEN} ✅ PM2 ${pm2_version} instalado para o usuário deploy${GRAY_LIGHT}\n"
  fi
  
  printf "\n${GREEN} ✅ Ambiente verificado com sucesso! Pronto para prosseguir.${GRAY_LIGHT}\n"
  sleep 2
  return 0
}

system_fail2ban_install() {
  print_banner
  printf "${WHITE} 💻 Instalando fail2ban...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  sudo su - root <<EOF
  sudo apt install fail2ban -y && sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
EOF
  sleep 2
}

system_fail2ban_conf() {
  print_banner
  printf "${WHITE} 💻 Configurando o fail2ban...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  sudo su - root <<EOF
  sudo systemctl enable fail2ban
  sudo systemctl start fail2ban
EOF
  sleep 2
}

system_firewall_conf() {
  print_banner
  printf "${WHITE} 💻 Configurando o firewall...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  sudo su - root <<EOF
  sudo ufw default allow outgoing
  sudo ufw default deny incoming
  sudo ufw allow ssh
  sudo ufw allow 22
  sudo ufw allow 80
  sudo ufw allow 443
  sudo ufw enable
EOF
  sleep 2
}

system_nginx_install() {
  print_banner
  printf "${WHITE} 💻 Verificando Nginx...${GRAY_LIGHT}"
  printf "\n\n"
  
  # Verificar se o Nginx já está instalado e funcionando
  nginx_running=false
  if command -v nginx &> /dev/null && sudo systemctl is-active --quiet nginx; then
    nginx_running=true
    nginx_version=$(nginx -v 2>&1 | grep -o 'nginx/[0-9.]*' | cut -d/ -f2)
    printf "${GREEN} ✅ Nginx versão ${nginx_version} já está instalado e rodando${GRAY_LIGHT}\n"
  fi
  
  if [ "$nginx_running" = "true" ] && [ "$use_existing_components" = "true" ]; then
    printf "${GREEN} ✅ Usando instalação existente do Nginx${GRAY_LIGHT}\n"
    
    # Verificar se o site padrão está ativo e remover se necessário
    if [ -f "/etc/nginx/sites-enabled/default" ]; then
      printf "${YELLOW} ⚠️ O site padrão do Nginx está ativo. Deseja removê-lo? (Y/n)${GRAY_LIGHT} "
      read -n 1 -r
      printf "\n"
      
      if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo rm -f /etc/nginx/sites-enabled/default
        sudo rm -f /etc/nginx/sites-available/default
        printf "${GREEN} ✅ Site padrão do Nginx removido${GRAY_LIGHT}\n"
      fi
    fi
  else
    printf "${YELLOW} ⚠️ Nginx não detectado ou reinstalação solicitada. Instalando...${GRAY_LIGHT}\n"
    
    # Código original para instalar o Nginx
    sudo su - root <<EOF
    sudo apt install -y nginx
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/sites-available/default
EOF
  fi
  
  printf "\n${GREEN} ✅ Verificação e configuração do Nginx concluída!${GRAY_LIGHT}\n"
  sleep 2
}

system_certbot_install() {
  print_banner
  printf "${WHITE} 💻 Instalando certbot...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Remover instalação anterior do certbot
  sudo apt-get remove -y certbot &>/dev/null || true
  
  # Instalar via snap
  sudo snap install --classic certbot
  
  # Criar link simbólico
  sudo ln -sf /snap/bin/certbot /usr/bin/certbot
  
  # Verificar instalação
  if command -v certbot &> /dev/null; then
    printf "\n${GREEN} ✅ Certbot instalado com sucesso!${GRAY_LIGHT}"
  else
    printf "\n${RED} ⚠️ Falha ao instalar Certbot. Tentando método alternativo...${GRAY_LIGHT}"
    sudo apt-get update
    sudo apt-get install -y certbot python3-certbot-nginx
  fi
  
  sleep 2
}

system_nginx_conf() {
  print_banner
  printf "${WHITE} 💻 Configurando nginx...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
sudo su - root << EOF
cat > /etc/nginx/conf.d/deploy.conf << 'END'
client_max_body_size 100M;
END
EOF
  sleep 2
}

system_nginx_restart() {
  print_banner
  printf "${WHITE} 💻 Reiniciando nginx...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  sudo su - root <<EOF
  service nginx restart
EOF
  sleep 2
}

system_certbot_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando certbot, Já estamos perto do fim...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Extrair domínios sem o protocolo https://
  frontend_domain=$(echo "${frontend_url}" | sed 's~^https://~~')
  backend_domain=$(echo "${backend_url}" | sed 's~^https://~~')
  
  # Verificar se os domínios foram extraídos corretamente
  if [ -z "$frontend_domain" ] || [ -z "$backend_domain" ]; then
    printf "\n${RED} ⚠️ Erro ao extrair domínios das URLs. Verifique as URLs fornecidas.${GRAY_LIGHT}"
    printf "\n Frontend: ${frontend_url}"
    printf "\n Backend: ${backend_url}"
    sleep 5
    return 1
  fi
  
  # Verificar se o nginx está rodando
  if ! sudo systemctl is-active --quiet nginx; then
    printf "\n${RED} ⚠️ Nginx não está rodando. Tentando iniciar...${GRAY_LIGHT}"
    sudo systemctl start nginx
    sleep 3
    
    if ! sudo systemctl is-active --quiet nginx; then
      printf "\n${RED} ⚠️ Falha ao iniciar Nginx. Certbot pode falhar.${GRAY_LIGHT}"
      sleep 5
    fi
  fi
  
  # Configurar um email para o certbot
  if [ -z "$deploy_email" ]; then
    deploy_email="admin@${frontend_domain}"
    printf "\n${YELLOW} ⚠️ Email não definido. Usando ${deploy_email} como padrão.${GRAY_LIGHT}"
  fi
  
  # Executar certbot para os domínios
  printf "\n${WHITE} 🔄 Executando certbot para ${frontend_domain} e ${backend_domain}...${GRAY_LIGHT}"
  sudo certbot --nginx --agree-tos --non-interactive -m "${deploy_email}" --domains "${frontend_domain},${backend_domain}" --redirect
  
  # Verificar resultado
  if [ $? -eq 0 ]; then
    printf "\n${GREEN} ✅ Certificados SSL instalados com sucesso!${GRAY_LIGHT}"
  else
    printf "\n${RED} ⚠️ Falha ao instalar certificados SSL. Tentando método alternativo...${GRAY_LIGHT}"
    
    # Tentar executar para cada domínio separadamente
    sudo certbot --nginx --agree-tos --non-interactive -m "${deploy_email}" --domains "${frontend_domain}" --redirect
    sudo certbot --nginx --agree-tos --non-interactive -m "${deploy_email}" --domains "${backend_domain}" --redirect
  fi
  
  # Reiniciar nginx para aplicar as alterações
  sudo systemctl restart nginx
  
  sleep 2
}

system_delete() {
  print_banner
  printf "${WHITE} 💻 Digite o nome da instância que deseja remover:${GRAY_LIGHT}"
  printf "\n\n"
  read -p "> " instancia_delete
  
  if [ -z "$instancia_delete" ]; then
    printf "\n${RED} ⚠️ O nome da instância não pode ficar vazio!${GRAY_LIGHT}"
    printf "\n\n"
    return
  fi
  
  if [ ! -d "/home/deploy/${instancia_delete}" ]; then
    printf "\n${RED} ⚠️ Instância não encontrada!${GRAY_LIGHT}"
    printf "\n\n"
    return
  fi
  
  print_banner
  printf "${RED} ⚠️ ATENÇÃO! Esta operação irá remover completamente a instância ${instancia_delete}${GRAY_LIGHT}"
  printf "\n\n"
  printf "${RED} ⚠️ Isso inclui todos os dados, arquivos e configurações!${GRAY_LIGHT}"
  printf "\n\n"
  read -p "Tem certeza que deseja continuar? (y/N) " -n 1 -r
  printf "\n\n"
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf "${WHITE} ✔️ Operação cancelada!${GRAY_LIGHT}"
    printf "\n\n"
    return
  fi
  
  # Parar e remover processos do PM2
  sudo su - deploy <<EOF
    pm2 stop ${instancia_delete}-backend
    pm2 delete ${instancia_delete}-backend
    pm2 save
EOF
  
  # Remover banco de dados PostgreSQL
  sudo su - postgres <<EOF
    dropdb ${instancia_delete}
    dropuser ${instancia_delete}
EOF
  
  # Remover arquivos do sistema
  sudo rm -rf /home/deploy/${instancia_delete}
  
  # Remover configurações do nginx
  sudo rm -f /etc/nginx/sites-enabled/${instancia_delete}-backend
  sudo rm -f /etc/nginx/sites-enabled/${instancia_delete}-frontend
  sudo rm -f /etc/nginx/sites-available/${instancia_delete}-backend
  sudo rm -f /etc/nginx/sites-available/${instancia_delete}-frontend
  
  # Recarregar nginx
  sudo systemctl reload nginx
  
  print_banner
  printf "${GREEN} ✅ Sistema removido com sucesso!${GRAY_LIGHT}"
  printf "\n\n"
  
  # Se for a última instância, oferecer remoção completa
  if [ -z "$(ls -A /home/deploy/)" ]; then
    printf "${WHITE} 📝 Nenhuma outra instância encontrada. Deseja remover todos os programas instalados?${GRAY_LIGHT}"
    printf "\n\n"
    read -p "Remover programas? (y/N) " -n 1 -r
    printf "\n\n"
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      # Remover PostgreSQL
      sudo apt-get remove --purge -y postgresql*
      
      # Remover Redis
      sudo apt-get remove --purge -y redis-server
      
      # Remover Nginx
      sudo apt-get remove --purge -y nginx
      
      # Remover Node.js
      sudo apt-get remove --purge -y nodejs
      
      # Remover PM2
      sudo npm uninstall -g pm2
      
      # Remover certbot
      sudo snap remove certbot
      
      # Remover usuário deploy
      sudo userdel -r deploy
      
      # Limpar pacotes não utilizados
      sudo apt-get autoremove -y
      sudo apt-get clean
      
      print_banner
      printf "${GREEN} ✅ Todos os programas foram removidos com sucesso!${GRAY_LIGHT}"
      printf "\n\n"
    fi
  fi
}
