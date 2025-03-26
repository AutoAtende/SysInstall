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
  printf "${WHITE} 💻 Instalando Node.js 20.x e PostgreSQL 16...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  
  # Instalando Node.js diretamente via NodeSource (método mais confiável)
  sudo su - root <<EOF
  # Remover versões antigas do Node.js, se existirem
  apt-get remove -y nodejs npm &>/dev/null || true
  
  # Adicionar repositório NodeSource para Node.js 20.x
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  
  # Instalar Node.js
  apt-get install -y nodejs
  
  # Verificar a instalação
  node -v
  npm -v
  
  # Instalar PM2 globalmente para todos os usuários
  npm install -g pm2@latest
  
  # Garantir que o usuário deploy possa executar PM2
  if id "deploy" &>/dev/null; then
    chown -R deploy:deploy /home/deploy/.pm2 &>/dev/null || true
    pm2 startup ubuntu -u deploy || true
    env PATH=\$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u deploy --hp /home/deploy || true
  fi
  
  # Instalando PostgreSQL 16
  printf "\n${WHITE} 💻 Instalando PostgreSQL 16...${GRAY_LIGHT}"
  sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt \$(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
  sudo apt-get update -y
  sudo apt-get -y install postgresql-16
  
  sudo systemctl enable postgresql
  sudo systemctl start postgresql
  
  # Configurar fuso horário
  sudo timedatectl set-timezone America/Sao_Paulo
EOF

  # Para usuário deploy, garantir acesso ao Node.js
  if id "deploy" &>/dev/null; then
    sudo su - deploy <<EOF
    # Verificar Node.js
    node -v
    npm -v
EOF
  fi

  # Verificar que o PM2 está instalado corretamente
  printf "\n${WHITE} 🔄 Verificando instalação do PM2...${GRAY_LIGHT}\n"
  if command -v pm2 &>/dev/null; then
    printf "${GREEN} ✅ PM2 instalado com sucesso!${GRAY_LIGHT}\n"
  else
    printf "${RED} ⚠️ Erro: PM2 não foi instalado corretamente.${GRAY_LIGHT}\n"
    printf "${YELLOW} Tentando instalar novamente...${GRAY_LIGHT}\n"
    
    sudo npm install -g pm2@latest
    
    if command -v pm2 &>/dev/null; then
      printf "${GREEN} ✅ PM2 instalado com sucesso na segunda tentativa!${GRAY_LIGHT}\n"
    else
      printf "${RED} ⚠️ Falha ao instalar PM2. Continuando a instalação...${GRAY_LIGHT}\n"
    fi
  fi
  
  # Verificar a instalação do PostgreSQL
  printf "\n${WHITE} 🔄 Verificando instalação do PostgreSQL...${GRAY_LIGHT}\n"
  if sudo systemctl is-active --quiet postgresql; then
    printf "${GREEN} ✅ PostgreSQL 16 instalado e rodando!${GRAY_LIGHT}\n"
  else
    printf "${RED} ⚠️ PostgreSQL não parece estar funcionando. Tentando iniciar...${GRAY_LIGHT}\n"
    sudo systemctl start postgresql
    
    if sudo systemctl is-active --quiet postgresql; then
      printf "${GREEN} ✅ PostgreSQL iniciado com sucesso!${GRAY_LIGHT}\n"
    else
      printf "${RED} ⚠️ Falha ao iniciar PostgreSQL. Revise a instalação manualmente.${GRAY_LIGHT}\n"
    fi
  fi
  
  sleep 2
}

system_redis_install() {
  print_banner
  printf "${WHITE} 💻 Instalando e configurando Redis...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  sudo su - root <<EOF
  # Adicionar repositório do Redis
  curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb \$(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list
  
  # Atualizar e instalar Redis (sem especificar versão exata)
  sudo apt update
  sudo apt install -y redis-server
  
  # Configurando Redis
  sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.backup
  
  # Atualizando configurações do Redis
  sudo sed -i 's/^bind 127.0.0.1/bind 127.0.0.1/' /etc/redis/redis.conf
  sudo sed -i "s/# requirepass foobared/requirepass ${mysql_root_password}/" /etc/redis/redis.conf
  sudo sed -i 's/# maxmemory <bytes>/maxmemory 2gb/' /etc/redis/redis.conf
  sudo sed -i 's/# maxmemory-policy noeviction/maxmemory-policy noeviction/' /etc/redis/redis.conf
  
  # Reiniciando serviço
  sudo systemctl enable redis-server
  sudo systemctl restart redis-server
EOF
  sleep 2
}

system_create_user() {
    print_banner
    printf "${WHITE} 💻 Criando usuário deploy...${GRAY_LIGHT}"
    printf "\n\n"

    # Remover usuário e grupo se existirem
    printf "${WHITE} 🔄 Removendo usuário existente para criar um novo...${GRAY_LIGHT}"
    sudo userdel -rf deploy >/dev/null 2>&1 || true
    sudo groupdel deploy >/dev/null 2>&1 || true
    sudo rm -rf /home/deploy >/dev/null 2>&1 || true
    printf " Feito.\n"

    # Criar grupo deploy
    printf "${WHITE} 🔄 Criando grupo deploy...${GRAY_LIGHT}"
    sudo groupadd deploy
    printf " Feito.\n"

    # Criar usuário deploy com senha definida diretamente
    printf "${WHITE} 🔄 Criando usuário deploy...${GRAY_LIGHT}"
    sudo useradd -m -s /bin/bash -g deploy deploy
    printf " Feito.\n"

    # Definir senha diretamente, sem interação
    printf "${WHITE} 🔄 Configurando senha...${GRAY_LIGHT}"
    echo "deploy:${mysql_root_password}" | sudo chpasswd
    printf " Feito.\n"

    # Adicionar ao grupo sudo
    printf "${WHITE} 🔄 Adicionando ao grupo sudo...${GRAY_LIGHT}"
    sudo usermod -aG sudo deploy
    printf " Feito.\n"

    # Ajustar permissões do diretório home
    printf "${WHITE} 🔄 Configurando permissões...${GRAY_LIGHT}"
    if [ -d "/home/deploy" ]; then
        sudo chown -R deploy:deploy /home/deploy
        sudo chmod 755 /home/deploy
        printf " Feito.\n"
    else
        printf "\n${RED} ⚠️ Erro: Diretório /home/deploy não foi criado!${GRAY_LIGHT}"
        printf "\n\n"
        sleep 5
        exit 1
    fi

    # Verificar se o usuário foi criado corretamente
    if id "deploy" >/dev/null 2>&1; then
        printf "\n${GREEN} ✅ Usuário deploy criado com sucesso!${GRAY_LIGHT}"
        printf "\n\n"
    else
        printf "\n${RED} ⚠️ Erro: Falha ao criar usuário deploy!${GRAY_LIGHT}"
        printf "\n\n"
        sleep 5
        exit 1
    fi

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
  if sudo -u deploy git clone https://lucassaud:${token_code}@github.com/AutoAtende/Sys.git /home/deploy/empresa/ ; then
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
  printf "${WHITE} 💻 Instalando o pm2...${GRAY_LIGHT}\n\n"
  sudo su - root <<EOF
  npm install -g pm2@latest
  pm2 startup ubuntu
  env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u deploy --hp /home/deploy
EOF
  sleep 2
  printf "${WHITE} ✔️ pm2 instalado com sucesso!${GRAY_LIGHT}\n"
  sleep 2
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
  printf "${WHITE} 💻 Instalando nginx...${GRAY_LIGHT}"
  printf "\n\n"
  sleep 2
  sudo su - root <<EOF
  sudo apt install -y nginx
  rm /etc/nginx/sites-enabled/default
  rm /etc/nginx/sites-available/default
EOF
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