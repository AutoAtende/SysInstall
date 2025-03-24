#!/bin/bash

clean_redis() {
    printf "\n${WHITE} 🗑️ Limpando Redis...${GRAY_LIGHT}"
    
    # Encontrar a primeira pasta dentro de /home/deploy
    instance_dir=$(ls -d /home/deploy/*/ 2>/dev/null | head -n 1)
    
    if [ ! -z "$instance_dir" ]; then
        # Extrair a senha do Redis do arquivo .env
        env_file="${instance_dir}backend/.env"
        if [ -f "$env_file" ]; then
            redis_password=$(grep "REDIS_PASSWORD=" "$env_file" | cut -d '=' -f2)
            
            if [ ! -z "$redis_password" ]; then
                # Limpar Redis com autenticação
                redis-cli -a "$redis_password" FLUSHALL
            fi
        fi
    fi
}

software_delete() {
    print_banner
    printf "${WHITE} 💻 Removendo instalação existente do AutoAtende...${GRAY_LIGHT}"
    printf "\n\n"
    
    read -p "⚠️  Tem certeza que deseja remover completamente o AutoAtende? Esta ação não pode ser desfeita! (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf "\n${RED} ❌ Operação cancelada pelo usuário.${GRAY_LIGHT}"
        printf "\n\n"
        exit 1
    fi

    # Parar todos os serviços primeiro
    printf "\n${WHITE} 🛑 Parando serviços...${GRAY_LIGHT}"
    if id "deploy" &>/dev/null; then
        sudo su - deploy <<EOF || true
        pm2 delete all
        pm2 save
        pm2 cleardump
EOF
    fi

    # Remover Nginx sites
    printf "\n${WHITE} 🗑️ Removendo configurações do Nginx...${GRAY_LIGHT}"
    sudo find /etc/nginx/sites-enabled/ -type l -delete
    sudo find /etc/nginx/sites-available/ -type f -delete
    sudo systemctl restart nginx

    # Remover bancos de dados e usuário PostgreSQL
    printf "\n${WHITE} 🗑️ Removendo bancos de dados...${GRAY_LIGHT}"
    if command -v psql &>/dev/null; then
        # Obter lista de instâncias
        instances=$(ls -1 /home/deploy 2>/dev/null)
        if [ ! -z "$instances" ]; then
            for instance in $instances; do
                sudo su - postgres <<EOF
                dropdb --if-exists ${instance}
                dropuser --if-exists ${instance}
EOF
            done
        fi
    fi

    # Limpar Redis usando a nova função
    clean_redis

    # Remover diretórios e usuário deploy
    printf "\n${WHITE} 🗑️ Removendo arquivos e usuário deploy...${GRAY_LIGHT}"
    if id "deploy" &>/dev/null; then
        # Matar todos os processos do usuário deploy
        sudo pkill -u deploy || true
        
        # Remover PM2 startup
        sudo su - deploy <<EOF || true
        pm2 unstartup
EOF
        
        # Remover diretório home e usuário
        sudo rm -rf /home/deploy
        sudo userdel -f deploy
    fi

    # Remover PM2
    printf "\n${WHITE} 🗑️ Removendo PM2...${GRAY_LIGHT}"
    sudo npm uninstall -g pm2 || true

    printf "\n${GREEN} ✅ AutoAtende removido com sucesso!${GRAY_LIGHT}"
    printf "\n\n"
    
    read -p "Pressione ENTER para voltar ao menu principal..."
    inquiry_options
}

system_cleanup() {
    print_banner
    printf "${WHITE} 🧹 Limpando sistema e desfazendo alterações parciais...${GRAY_LIGHT}"
    printf "\n\n"
    
    read -p "⚠️  Tem certeza que deseja limpar todas as modificações feitas pelo instalador do AutoAtende? (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf "\n${RED} ❌ Operação cancelada pelo usuário.${GRAY_LIGHT}"
        printf "\n\n"
        read -p "Pressione ENTER para voltar ao menu principal..."
        inquiry_options
        return
    fi

    # 1. Remover usuário deploy se existir
    printf "\n${WHITE} 🗑️ Removendo usuário deploy...${GRAY_LIGHT}"
    if id "deploy" &>/dev/null; then
        sudo pkill -u deploy || true
        sudo userdel -rf deploy
        sudo groupdel deploy 2>/dev/null || true
    fi

    # 2. Remover banco de dados e usuário PostgreSQL
    printf "\n${WHITE} 🗑️ Removendo banco de dados...${GRAY_LIGHT}"
    if command -v psql &>/dev/null; then
        sudo su - postgres <<EOF 2>/dev/null || true
        dropdb --if-exists empresa
        dropuser --if-exists empresa
EOF
    fi

    # 3. Limpar Redis (opcional, caso tenha chegado nesse ponto)
    printf "\n${WHITE} 🗑️ Limpando Redis...${GRAY_LIGHT}"
    if systemctl is-active --quiet redis-server; then
        sudo systemctl stop redis-server
        sudo apt-get remove --purge -y redis-server redis-tools || true
        sudo rm -rf /etc/redis /var/lib/redis
        sudo rm -f /etc/apt/sources.list.d/redis.list
    fi

    # 4. Remover Node.js/NPM/PM2 do sistema
    printf "\n${WHITE} 🗑️ Removendo Node.js e PM2...${GRAY_LIGHT}"
    sudo npm uninstall -g pm2 || true
    
    # 5. Restaurar configurações de firewall
    printf "\n${WHITE} 🗑️ Restaurando configurações de firewall...${GRAY_LIGHT}"
    sudo ufw reset
    sudo ufw allow ssh
    sudo ufw --force enable

    # 6. Remover configurações do nginx
    printf "\n${WHITE} 🗑️ Removendo configurações do Nginx...${GRAY_LIGHT}"
    sudo rm -f /etc/nginx/conf.d/deploy.conf
    sudo rm -f /etc/nginx/sites-available/empresa-frontend
    sudo rm -f /etc/nginx/sites-available/empresa-backend
    sudo rm -f /etc/nginx/sites-enabled/empresa-frontend
    sudo rm -f /etc/nginx/sites-enabled/empresa-backend
    sudo systemctl restart nginx

    # 7. Remover fail2ban (opcional)
    printf "\n${WHITE} 🗑️ Removendo fail2ban...${GRAY_LIGHT}"
    sudo systemctl stop fail2ban || true
    sudo apt-get remove --purge -y fail2ban || true
    sudo rm -rf /etc/fail2ban

    # 8. Limpar arquivos temporários e logs
    printf "\n${WHITE} 🗑️ Limpando arquivos temporários...${GRAY_LIGHT}"
    sudo rm -rf /tmp/autoatende* 2>/dev/null || true

    # 9. Remover quaisquer pacotes que não sejam mais necessários
    printf "\n${WHITE} 🗑️ Removendo pacotes desnecessários...${GRAY_LIGHT}"
    sudo apt-get autoremove -y
    sudo apt-get clean

    printf "\n${GREEN} ✅ Sistema limpo com sucesso! Todas as modificações parciais foram desfeitas.${GRAY_LIGHT}"
    printf "\n\n"
    read -p "Pressione ENTER para voltar ao menu principal..."
    inquiry_options
}