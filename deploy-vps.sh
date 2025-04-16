#!/bin/bash

# Script para implantação simplificada do TrendPulse em VPS
# Este script deve ser executado na VPS

echo "==============================================="
echo "     Implantação Simplificada do TrendPulse    "
echo "==============================================="

APP_DIR="/var/www/trendpulse"
TEMP_DIR="/tmp/trendpulse-deploy"

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then 
  echo "Por favor, execute como root (use sudo)"
  exit 1
fi

# Criar diretório temporário
mkdir -p $TEMP_DIR
cd $TEMP_DIR

echo "Instalando dependências básicas..."
apt update
apt install -y curl wget git nginx

# Instalar Node.js
echo "Instalando Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Instalar PostgreSQL
echo "Instalando PostgreSQL..."
apt install -y postgresql postgresql-contrib

# Configurar banco de dados
echo "Configurando banco de dados..."
DB_USER="trendpulse"
DB_PASS="trendpulse123"
DB_NAME="trendpulse"

# Criar usuário e banco de dados PostgreSQL
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';" || echo "Usuário já existe"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;" || echo "Banco de dados já existe"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" || echo "Permissões já concedidas"

# Criar diretório da aplicação
echo "Criando diretório da aplicação..."
mkdir -p $APP_DIR
cd $APP_DIR

echo "Baixando código-fonte manualmente..."
# Opção 1: Usar wget para baixar um arquivo zip do GitHub (substitua pela URL correta)
# wget https://github.com/alexandrealx001/TrendBlogger/archive/refs/heads/main.zip
# unzip main.zip
# mv TrendBlogger-main/* .
# rm -rf TrendBlogger-main main.zip

# Opção 2: Clonar o repositório
git clone https://github.com/alexandrealx001/TrendBlogger.git .

# Criar arquivo .env
echo "Criando arquivo .env..."
cat > .env << EOF
# Conexão com o banco de dados PostgreSQL
DATABASE_URL=postgres://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME
PGUSER=$DB_USER
PGPASSWORD=$DB_PASS
PGDATABASE=$DB_NAME
PGHOST=localhost
PGPORT=5432

# Configuração do servidor
PORT=5000
NODE_ENV=production

# Sessão
SESSION_SECRET=chave_secreta_para_sessoes_87654321

# API Keys - Substitua com suas chaves
OPENAI_API_KEY=sua_chave_openai_aqui
GOOGLE_SEARCH_API_KEY=sua_chave_google_search_aqui
EOF

# Configurar o Nginx
echo "Configurando Nginx..."
cat > /etc/nginx/sites-available/trendpulse << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    client_max_body_size 5M;
}
EOF

# Ativar site no Nginx
ln -sf /etc/nginx/sites-available/trendpulse /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Instalar PM2
echo "Instalando PM2..."
npm install -g pm2

# Instalar dependências do projeto
echo "Instalando dependências do projeto..."
npm install

# Migrar banco de dados
echo "Migrando banco de dados..."
npm run db:push

# Construir o projeto
echo "Construindo o projeto..."
npm run build

# Iniciar com PM2
echo "Iniciando aplicação com PM2..."
pm2 start npm --name "trendpulse" -- start
pm2 save
pm2 startup

echo ""
echo "==============================================="
echo "      Implantação concluída com sucesso!      "
echo "==============================================="
echo ""
echo "IMPORTANTE: Você precisa adicionar suas chaves de API:"
echo "   - OPENAI_API_KEY"
echo "   - GOOGLE_SEARCH_API_KEY"
echo ""
echo "Para editar as chaves:"
echo "   sudo nano $APP_DIR/.env"
echo ""
echo "Seu blog deve estar disponível em:"
echo "   http://seu-endereco-ip"
echo ""
echo "Para ver o status da aplicação:"
echo "   pm2 status"
echo ""