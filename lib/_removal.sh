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

    # Verificar e parar serviços PM2 (com verificação)
    printf "\n${WHITE} 🛑 Parando serviços...${GRAY_LIGHT}"
    if id "deploy" &>/dev/null && command -v pm2 &>/dev/null; then
        sudo su - deploy <<EOF || true
        export NVM_DIR="/home/deploy/.nvm"
        [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
        if command -v pm2 &>/dev/null; then
            pm2 delete all || true
            pm2 save || true
            pm2 cleardump || true
        fi
EOF
    elif id "deploy" &>/dev/null; then
        printf "\n${YELLOW} ⚠️ PM2 não encontrado, ignorando...${GRAY_LIGHT}"
    fi

    # Remover Nginx sites (com verificação)
    printf "\n${WHITE} 🗑️ Removendo configurações do Nginx...${GRAY_LIGHT}"
    if [ -d "/etc/nginx" ]; then
        sudo find /etc/nginx/sites-enabled/ -type l -delete 2>/dev/null || true
        sudo find /etc/nginx/sites-available/ -name "empresa-*" -type f -delete 2>/dev/null || true
        sudo systemctl restart nginx 2>/dev/null || true
    else
        printf "\n${YELLOW} ⚠️ Nginx não encontrado, ignorando...${GRAY_LIGHT}"
    fi

    # Remover bancos de dados PostgreSQL (com verificação)
    printf "\n${WHITE} 🗑️ Removendo bancos de dados...${GRAY_LIGHT}"
    if command -v psql &>/dev/null; then
        sudo su - postgres <<EOF 2>/dev/null || true
        dropdb --if-exists empresa
        dropuser --if-exists empresa
EOF
    else
        printf "\n${YELLOW} ⚠️ PostgreSQL não encontrado, ignorando...${GRAY_LIGHT}"
    fi

    # Limpar Redis (com verificação)
    printf "\n${WHITE} 🗑️ Limpando Redis...${GRAY_LIGHT}"
    if command -v redis-cli &>/dev/null; then
        # Tenta limpar o Redis, sem exigir senha
        redis-cli FLUSHALL 2>/dev/null || true
        
        # Ou tenta parar o serviço
        sudo systemctl stop redis-server 2>/dev/null || true
    else
        printf "\n${YELLOW} ⚠️ Redis não encontrado, ignorando...${GRAY_LIGHT}"
    fi

    # Remover diretórios e usuário deploy (com verificação)
    printf "\n${WHITE} 🗑️ Removendo arquivos e usuário deploy...${GRAY_LIGHT}"
    if id "deploy" &>/dev/null; then
        # Matar todos os processos do usuário deploy
        sudo pkill -u deploy 2>/dev/null || true
        
        # Remover diretório home
        sudo rm -rf /home/deploy 2>/dev/null || true
        
        # Verificar se o usuário é o único membro do grupo
        if [ "$(getent group deploy | cut -d: -f4)" = "deploy" ]; then
            sudo userdel -rf deploy 2>/dev/null || true
        else
            sudo userdel -rf deploy 2>/dev/null || true
            printf "\n${YELLOW} ⚠️ Grupo 'deploy' não removido pois contém outros membros${GRAY_LIGHT}"
        fi
    else
        printf "\n${YELLOW} ⚠️ Usuário deploy não encontrado, ignorando...${GRAY_LIGHT}"
    fi

    # Remover PM2 (com verificação)
    printf "\n${WHITE} 🗑️ Removendo PM2...${GRAY_LIGHT}"
    if command -v npm &>/dev/null; then
        sudo npm uninstall -g pm2 2>/dev/null || true
    else
        printf "\n${YELLOW} ⚠️ NPM não encontrado, ignorando...${GRAY_LIGHT}"
    fi

    printf "\n${GREEN} ✅ AutoAtende removido com sucesso!${GRAY_LIGHT}"
    printf "\n\n"
    
    read -p "Pressione ENTER para voltar ao menu principal..."
    inquiry_options
}

system_cleanup() {
    print_banner
    printf "${WHITE} 🧹 Limpando sistema para nova instalação...${GRAY_LIGHT}"
    printf "\n\n"
    
    read -p "⚠️  Esta opção irá remover completamente todas as configurações do sistema. Continuar? (y/N) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        printf "\n${RED} ❌ Operação cancelada pelo usuário.${GRAY_LIGHT}"
        printf "\n\n"
        read -p "Pressione ENTER para voltar ao menu principal..."
        inquiry_options
        return
    fi

    # 1. Remover usuário deploy completamente
    printf "\n${WHITE} 🗑️ Removendo usuário deploy...${GRAY_LIGHT}"
    sudo pkill -u deploy 2>/dev/null || true
    sudo userdel -rf deploy 2>/dev/null || true
    sudo groupdel deploy 2>/dev/null || true
    sudo rm -rf /home/deploy 2>/dev/null || true

    # 2. Limpar PostgreSQL
    printf "\n${WHITE} 🗑️ Limpando PostgreSQL...${GRAY_LIGHT}"
    if command -v psql &>/dev/null; then
        sudo systemctl stop postgresql 2>/dev/null || true
        sudo su - postgres <<EOF 2>/dev/null || true
        dropdb --if-exists empresa
        dropuser --if-exists empresa
EOF
    fi

    # 3. Remover e limpar Redis completamente
    printf "\n${WHITE} 🗑️ Removendo Redis...${GRAY_LIGHT}"
    sudo systemctl stop redis-server 2>/dev/null || true
    sudo apt-get remove --purge -y redis-server redis-tools 2>/dev/null || true
    sudo apt-get autoremove -y 2>/dev/null || true
    sudo rm -rf /etc/redis /var/lib/redis 2>/dev/null || true
    sudo rm -f /etc/apt/sources.list.d/redis* 2>/dev/null || true

    # 4. Remover NodeJS/NVM e reiniciar
    printf "\n${WHITE} 🗑️ Removendo Node.js e NVM...${GRAY_LIGHT}"
    sudo apt-get remove --purge -y nodejs npm 2>/dev/null || true
    sudo rm -rf /usr/local/lib/node_modules 2>/dev/null || true
    sudo rm -rf /usr/local/bin/node 2>/dev/null || true
    sudo rm -rf /usr/local/bin/npm 2>/dev/null || true

    # 5. Limpar configurações Nginx
    printf "\n${WHITE} 🗑️ Limpando configurações do Nginx...${GRAY_LIGHT}"
    if [ -d "/etc/nginx" ]; then
        sudo find /etc/nginx/sites-enabled/ -type l -delete 2>/dev/null || true
        sudo find /etc/nginx/sites-available/ -name "empresa-*" -type f -delete 2>/dev/null || true
        sudo rm -f /etc/nginx/conf.d/deploy.conf 2>/dev/null || true
        sudo systemctl restart nginx 2>/dev/null || true
    fi

    # 6. Atualizar repositórios
    printf "\n${WHITE} 🔄 Atualizando repositórios...${GRAY_LIGHT}"
    sudo apt-get update 2>/dev/null || true

    # 7. Limpar e reiniciar UFW
    printf "\n${WHITE} 🔄 Reiniciando firewall...${GRAY_LIGHT}"
    sudo ufw --force reset 2>/dev/null || true
    sudo ufw --force enable 2>/dev/null || true
    sudo ufw allow ssh 2>/dev/null || true

    printf "\n${GREEN} ✅ Sistema limpo com sucesso! Pronto para nova instalação.${GRAY_LIGHT}"
    printf "\n\n"
    printf "${YELLOW} ⚠️ Recomenda-se reiniciar o servidor antes de tentar uma nova instalação.${GRAY_LIGHT}"
    printf "\n\n"
    read -p "Deseja reiniciar o sistema agora? (y/N) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo reboot
    else
        read -p "Pressione ENTER para voltar ao menu principal..."
        inquiry_options
    fi
}