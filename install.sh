#!/bin/bash

tput init

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  PROJECT_ROOT="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$PROJECT_ROOT/$SOURCE"
done
PROJECT_ROOT="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# required imports
source "${PROJECT_ROOT}"/variables/manifest.sh
source "${PROJECT_ROOT}"/utils/manifest.sh
source "${PROJECT_ROOT}"/lib/manifest.sh

# interactive CLI
inquiry_options



# system installation
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

# backend related
system_git_clone
backend_set_env
backend_redis_setup
backend_node_dependencies
backend_node_build
backend_db_migrate
backend_db_seed
backend_start_pm2
backend_nginx_setup

# frontend related
frontend_setup

# network related
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