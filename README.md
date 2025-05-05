# AutoAtende Installer

Este é o instalador oficial do AutoAtende, uma plataforma SaaS para gestão de atendimento e automação de WhatsApp.

## 🚀 Requisitos do Sistema

| Componente | Mínimo | Recomendado |
|------------|---------|-------------|
| CPU | 2 cores | 4 cores |
| Memória RAM | 8GB | 32GB ou mais |
| Armazenamento | 20GB | 100GB ou mais |
| Sistema Operacional | Ubuntu 20.04 | Ubuntu 24.04 |

## 📋 Pré-requisitos

- Acesso root ao servidor
- Domínios configurados para frontend e backend
- Token de acesso ao repositório do AutoAtende
- Nome do repositório a ser instalado

## 💻 Instalação Rápida

```bash
# Download e execução do instalador
sudo apt install -y git && git clone https://github.com/AutoAtende/SysInstall.git autoatende && sudo chmod -R 777 ./autoatende && cd ./autoatende && sudo ./install.sh
```

## 🛠️ O que o instalador faz?

1. **Instalação Primária**
   - Configura todo o ambiente necessário
   - Instala e configura:
     - Node.js 20.19.0 (via NVM)
     - PostgreSQL 16
     - Redis 7.4
     - Nginx
     - Certbot (Let's Encrypt)
   - Configura firewall (UFW)
   - Cria usuário deploy

2. **Instalação de Instância**
   - Clona o repositório específico
   - Configura banco de dados
   - Configura variáveis de ambiente
   - Instala dependências
   - Configura nginx
   - Configura SSL

3. **Otimização do Sistema**
   - Otimiza PostgreSQL
   - Otimiza Redis
   - Otimiza Nginx
   - Otimiza Node.js

## 📝 Opções do Menu

1. **Menu Principal**
   - Instalar
   - Desistalar
   - Sair

## 📊 Portas Utilizadas

| Porta | Serviço |
|-------|---------|
| 22 | SSH |
| 80 | HTTP |
| 443 | HTTPS |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 3000 | Frontend (desenvolvimento) |
| 8080 | Backend (desenvolvimento) |


## ⚙️ Configurações Padrão

- PostgreSQL: Configurado para performance otimizada
- Redis: Configurado com senha e limites de memória
- Nginx: Otimizado para melhor performance
- PM2: Configurado para gerenciamento de processos Node.js

## 🛟 Suporte

Para suporte, entre em contato através do nosso canal oficial: [Suporte AutoAtende](lucas@autoatende.com)

## 🔒 Segurança

- Firewall configurado com regras restritas
- Senhas geradas de forma segura
- Proteção contra acessos indevidos
- SSL/TLS via Let's Encrypt

## 🤝 Contribuindo

Para contribuir com este projeto:

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📜 Licença

Este projeto está sob a licença [MIT](https://opensource.org/licenses/MIT).
