#!/bin/bash

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

get_instancia_add() {
  print_banner
  printf "${WHITE} 💻 Digite o nome da empresa/instância (letras minúsculas, sem espaços/caracteres especiais):${GRAY_LIGHT}"
  printf "\n\n"
  read -p "> " instancia_add

  if [[ ! $instancia_add =~ ^[a-z0-9]+$ ]]; then
    printf "\n${RED} ⚠️ Use apenas letras minúsculas e números!${GRAY_LIGHT}"
    printf "\n\n"
    get_instancia_add
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
}

get_urls() {
  get_mysql_root_password
  get_token_code
  get_instancia_add
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
    printf "   [3] Limpar Sistema (Desfazer instalação parcial)\n"
    printf "\n"
    read -p "> " option

    case "${option}" in
        1) 
            if [ -d "/home/deploy" ] && [ ! -z "$(ls -A /home/deploy/)" ]; then
                printf "\n${RED} ⚠️ Foi detectada uma instalação existente do AutoAtende!${GRAY_LIGHT}"
                printf "\n${WHITE} Use a opção 2 para remover a instalação atual antes de prosseguir.${GRAY_LIGHT}"
                printf "\n\n"
                read -p "Pressione ENTER para voltar ao menu principal..."
                inquiry_options
            else
                get_urls
                show_vars
            fi
            ;;
        2)
            software_delete
            ;;
        3)
            system_cleanup
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