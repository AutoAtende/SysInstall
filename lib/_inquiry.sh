#!/bin/bash

detect_installed_components() {
  print_banner
  printf "${WHITE} 💻 Detectando componentes já instalados...${GRAY_LIGHT}"
  printf "\n\n"
  
  # Verificar Nginx
  nginx_installed=false
  if command -v nginx &> /dev/null && sudo systemctl is-active --quiet nginx; then
    nginx_installed=true
    printf "${GREEN} ✅ Nginx detectado e ativo${GRAY_LIGHT}\n"
  else
    printf "${YELLOW} ⚠️ Nginx não detectado ou não está ativo${GRAY_LIGHT}\n"
  fi

  # Verificar PostgreSQL
  postgresql_installed=false
  if command -v psql &> /dev/null && sudo systemctl is-active --quiet postgresql; then
    postgresql_installed=true
    printf "${GREEN} ✅ PostgreSQL detectado e ativo${GRAY_LIGHT}\n"
  else
    printf "${YELLOW} ⚠️ PostgreSQL não detectado ou não está ativo${GRAY_LIGHT}\n"
  fi

  # Verificar Redis
  redis_installed=false
  if command -v redis-cli &> /dev/null && sudo systemctl is-active --quiet redis-server; then
    redis_installed=true
    printf "${GREEN} ✅ Redis detectado e ativo${GRAY_LIGHT}\n"
  else
    printf "${YELLOW} ⚠️ Redis não detectado ou não está ativo${GRAY_LIGHT}\n"
  fi

  # Verificar Node.js para o usuário deploy (se o usuário existir)
  nodejs_installed=false
  deploy_exists=false
  if id "deploy" &>/dev/null; then
    deploy_exists=true
    printf "${GREEN} ✅ Usuário deploy já existe${GRAY_LIGHT}\n"
    
    # Verificar Node.js para o usuário deploy
    node_version=$(sudo -u deploy bash -c 'command -v node &> /dev/null && node -v' 2>/dev/null || echo "")
    if [ ! -z "$node_version" ]; then
      nodejs_installed=true
      printf "${GREEN} ✅ Node.js detectado para usuário deploy: ${node_version}${GRAY_LIGHT}\n"
    else
      # Verificar se o NVM está instalado
      nvm_exists=$(sudo -u deploy bash -c 'test -d "$HOME/.nvm" && echo "true" || echo "false"')
      if [ "$nvm_exists" = "true" ]; then
        nvm_node_version=$(sudo -u deploy bash -c 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"; node -v' 2>/dev/null || echo "")
        if [ ! -z "$nvm_node_version" ]; then
          nodejs_installed=true
          printf "${GREEN} ✅ Node.js via NVM detectado: ${nvm_node_version}${GRAY_LIGHT}\n"
        else
          printf "${YELLOW} ⚠️ NVM encontrado, mas Node.js não está configurado${GRAY_LIGHT}\n"
        fi
      else
        printf "${YELLOW} ⚠️ Node.js não detectado para usuário deploy${GRAY_LIGHT}\n"
      fi
    fi
    
    # Verificar PM2
    pm2_exists=$(sudo -u deploy bash -c 'command -v pm2 &> /dev/null && echo "true" || echo "false"')
    if [ "$pm2_exists" = "true" ]; then
      pm2_installed=true
      pm2_version=$(sudo -u deploy bash -c 'pm2 --version' 2>/dev/null || echo "")
      printf "${GREEN} ✅ PM2 detectado: ${pm2_version}${GRAY_LIGHT}\n"
    else
      pm2_installed=false
      printf "${YELLOW} ⚠️ PM2 não detectado para usuário deploy${GRAY_LIGHT}\n"
    fi
  else
    printf "${YELLOW} ⚠️ Usuário deploy não existe${GRAY_LIGHT}\n"
  fi
  
  printf "\n${WHITE} 💻 Como deseja prosseguir?${GRAY_LIGHT}\n\n"
  printf "   [1] Usar componentes existentes quando possível (recomendado)\n"
  printf "   [2] Tentar reinstalar todos os componentes (pode causar conflitos)\n"
  printf "\n"
  read -p "> " use_existing
  
  case "${use_existing}" in
    1)
      use_existing_components=true
      ;;
    2)
      use_existing_components=false
      ;;
    *)
      printf "\n${YELLOW} ⚠️ Opção inválida. Usando componentes existentes por segurança.${GRAY_LIGHT}\n"
      use_existing_components=true
      ;;
  esac
  
  sleep 2
}

get_mysql_root_password() {
  print_banner
  printf "${WHITE} 💻 Insira senha para o usuario Deploy e Banco de Dados:${GRAY_LIGHT}"
  printf "\n\n"
  printf "${YELLOW} A senha precisa ter no mínimo 8 caracteres${GRAY_LIGHT}"
  printf "\n\n"
  read -s -p "> " mysql_root_password
  printf "\n"
  
  if [ ${#mysql_root_password} -lt 8 ]; then
    printf "\n${RED} ⚠️ A senha precisa ter no mínimo 8 caracteres!${GRAY_LIGHT}"
    printf "\n\n"
    get_mysql_root_password
  fi

  printf "\n${WHITE} 💻 Digite a senha novamente:${GRAY_LIGHT}"
  printf "\n\n"
  read -s -p "> " mysql_root_password_confirm
  printf "\n"

  if [ "$mysql_root_password" != "$mysql_root_password_confirm" ]; then
    printf "\n${RED} ⚠️ As senhas não conferem!${GRAY_LIGHT}"
    printf "\n\n"
    get_mysql_root_password
  fi
}

get_empresa_nome() {
  print_banner
  printf "${WHITE} 💻 Digite o nome da empresa para o PWA (Nome que aparecerá no celular):${GRAY_LIGHT}"
  printf "\n\n"
  read -p "> " empresa_nome

  if [ -z "$empresa_nome" ]; then
    printf "\n${RED} ⚠️ O nome da empresa não pode ficar vazio!${GRAY_LIGHT}"
    printf "\n\n"
    get_empresa_nome
  fi
}

get_token_code() {
  print_banner
  printf "${WHITE} 💻 Digite o token para baixar o código:${GRAY_LIGHT}"
  printf "\n\n"
  read -p "> " token_code

  if [ -z "$token_code" ]; then
    printf "\n${RED} ⚠️ O token não pode ficar vazio!${GRAY_LIGHT}"
    printf "\n\n"
    get_token_code
  fi
}

get_frontend_url() {
  print_banner
  printf "${WHITE} 💻 Digite a url do frontend (ex: app.seudominio.com.br):${GRAY_LIGHT}"
  printf "\n\n"
  read -p "> " frontend_url

  if [[ ! $frontend_url =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    printf "\n${RED} ⚠️ Domínio inválido!${GRAY_LIGHT}"
    printf "\n\n"
    get_frontend_url
  fi
  
}

get_backend_url() {
  print_banner
  printf "${WHITE} 💻 Digite a url do backend (ex: api.seudominio.com.br):${GRAY_LIGHT}"
  printf "\n\n"
  read -p "> " backend_url

  if [[ ! $backend_url =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
    printf "\n${RED} ⚠️ Domínio inválido!${GRAY_LIGHT}"
    printf "\n\n"
    get_backend_url
  fi
  
}

set_default_variables() {
  max_whats=1000
  max_user=1000
  backend_port=4029
  redis_port=6379
  instancia_add=empresa
}

get_urls() {
  get_mysql_root_password
  get_token_code
  get_empresa_nome
  get_frontend_url
  get_backend_url
  set_default_variables
}

show_vars() {
  print_banner
  printf "${WHITE} 📝 Confira os dados informados:${GRAY_LIGHT}"
  printf "\n\n"
  printf " Nome da empresa: $instancia_add\n"
  printf " Nome para PWA: $empresa_nome\n"
  printf " URL Frontend: $frontend_url\n"
  printf " URL Backend: $backend_url\n"
  printf " Porta Backend: $backend_port\n"
  printf " Porta Redis: $redis_port\n"
  printf " Limite Usuários: $max_user\n"
  printf " Limite Conexões: $max_whats\n"
  printf "\n"
  read -p "Os dados estão corretos? (y/N) " -n 1 -r
  printf "\n\n"

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    printf "${RED} ⚠️ Instalação cancelada! Execute novamente para recomeçar.${GRAY_LIGHT}"
    printf "\n\n"
    exit 1
  fi
}

inquiry_options() {
    print_banner
    printf "${WHITE} 💻 Bem vindo(a) ao AutoAtende! Selecione uma opção:${GRAY_LIGHT}"
    printf "\n\n"
    printf "   [1] Instalar AutoAtende\n"
    printf "   [2] Remover AutoAtende\n"
    printf "   [3] Limpar Sistema (Preparar para nova instalação)\n"
    printf "   [4] Sair\n"
    printf "\n"
    read -p "> " option

    case "${option}" in
        1) 
            detect_installed_components
            get_urls
            show_vars
            ;;
        2)
            software_delete
            ;;
        3)
            system_cleanup
            ;;
        4)
            printf "\n${GREEN} ✅ Saindo...${GRAY_LIGHT}\n\n"
            exit 0
            ;;
        *)
            printf "\n${RED} ⚠️ Opção inválida!${GRAY_LIGHT}"
            printf "\n\n"
            sleep 2
            inquiry_options
            ;;
    esac
}

check_previous_installation() {
  print_banner
  printf "${WHITE} 💻 Verificando instalações existentes...${GRAY_LIGHT}"
  printf "\n\n"

  if [ -d "/home/deploy" ] && [ ! -z "$(ls -A /home/deploy/)" ]; then
    printf "${RED} ⚠️ Foi detectada uma instalação existente do AutoAtende!${GRAY_LIGHT}"
    printf "\n\n"
    printf "${WHITE} O AutoAtende só pode ter uma instalação por servidor.${GRAY_LIGHT}"
    printf "\n\n"
    printf "${WHITE} Por favor, use a opção 2 no menu principal para remover a instalação atual antes de prosseguir.${GRAY_LIGHT}"
    printf "\n\n"
    return 1
  fi
  return 0
}