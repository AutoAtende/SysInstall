#!/bin/bash

tput init

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  PROJECT_ROOT="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$PROJECT_ROOT/$SOURCE"
done
PROJECT_ROOT="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Required imports
source "${PROJECT_ROOT}"/variables/manifest.sh
source "${PROJECT_ROOT}"/utils/manifest.sh
source "${PROJECT_ROOT}"/lib/manifest.sh

# Gerar JWT Secrets antes de qualquer interação
system_generate_jwt_secrets

# Interactive CLI
inquiry_options

# System installation
system_update

# Criar usuário antes das dependências
system_create_user

system_node_install
system_redis_install
system_pm2_install
system_fail2ban_install
system_fail2ban_conf
system_firewall_conf
system_nginx_install
system_certbot_install

# Backend related
system_git_clone

# Verificar se o clone foi bem-sucedido antes de continuar
if [ ! -d "/home/deploy/empresa/backend" ]; then
  print_banner
  printf "${RED} ⚠️ Falha ao clonar o repositório. Instalação interrompida.${GRAY_LIGHT}"
  printf "\n\n"
  exit 1
fi

backend_set_env
backend_redis_setup
backend_node_dependencies
backend_node_build
backend_db_migrate
backend_db_seed
backend_start_pm2
backend_nginx_setup

# Frontend related
frontend_setup

# Network related
system_nginx_conf
system_nginx_restart
system_certbot_setup

# Final instructions
print_banner
printf "${GREEN} ✅ Instalação do AutoAtende concluída com sucesso!${GRAY_LIGHT}"
printf "\n\n"
printf "${WHITE} 📝 Informações de acesso:${GRAY_LIGHT}"
printf "\n\n"
printf "${WHITE} Frontend: ${GRAY_LIGHT}${frontend_url}"
printf "\n"
printf "${WHITE} Backend: ${GRAY_LIGHT}${backend_url}"
printf "\n\n"
printf "${WHITE} Guarde estas informações em um local seguro!${GRAY_LIGHT}"
printf "\n\n"
printf "${WHITE} Para acessar o sistema, utilize:${GRAY_LIGHT}"
printf "\n"
printf "${WHITE} Usuário: ${GRAY_LIGHT}admin@autoatende.com"
printf "\n"
printf "${WHITE} Senha: ${GRAY_LIGHT}mudar@123"
printf "\n\n"
printf "${RED} ⚠️ IMPORTANTE: Altere a senha padrão após o primeiro acesso!${GRAY_LIGHT}"
printf "\n\n"

# Verificar se todos os serviços estão rodando após a instalação
printf "${WHITE} 🔄 Verificando serviços...${GRAY_LIGHT}"
printf "\n\n"

# Verificar PostgreSQL
if sudo systemctl is-active --quiet postgresql; then
  printf "${GREEN} ✅ PostgreSQL: Ativo${GRAY_LIGHT}\n"
else
  printf "${RED} ⚠️ PostgreSQL: Inativo${GRAY_LIGHT}\n"
fi

# Verificar Redis
if sudo systemctl is-active --quiet redis-server; then
  printf "${GREEN} ✅ Redis: Ativo${GRAY_LIGHT}\n"
else
  printf "${RED} ⚠️ Redis: Inativo${GRAY_LIGHT}\n"
fi

# Verificar Nginx
if sudo systemctl is-active --quiet nginx; then
  printf "${GREEN} ✅ Nginx: Ativo${GRAY_LIGHT}\n"
else
  printf "${RED} ⚠️ Nginx: Inativo${GRAY_LIGHT}\n"
fi

# Verificar PM2
if sudo -u deploy bash -c "pm2 list | grep -q empresa-backend"; then
  printf "${GREEN} ✅ PM2 (empresa-backend): Ativo${GRAY_LIGHT}\n"
else
  printf "${RED} ⚠️ PM2 (empresa-backend): Inativo${GRAY_LIGHT}\n"
  printf "${YELLOW} Tentando iniciar novamente...${GRAY_LIGHT}\n"
  sudo -u deploy bash -c "cd /home/deploy/empresa/backend && pm2 start ecosystem.config.js && pm2 save"
fi

# Verificar se os domínios estão acessíveis
printf "\n${WHITE} 📡 Aguarde um momento enquanto configuramos os certificados SSL...${GRAY_LIGHT}\n"
printf "${YELLOW} Pode levar alguns minutos até que os certificados SSL sejam ativados.${GRAY_LIGHT}\n\n"

printf "${WHITE} Instalação concluída! Obrigado por escolher o AutoAtende.${GRAY_LIGHT}\n\n"