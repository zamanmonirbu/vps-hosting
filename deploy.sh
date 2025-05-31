#!/bin/bash

# Replace these values before running
REPO_URL="https://github.com/your-username/your-repo.git"
APP_NAME="my-mern-app"
DOMAIN="your-domain.com"
PORT=5000  # change this to your Node.js server port

echo "🔐 Updating system..."
sudo apt update && sudo apt upgrade -y

echo "📦 Installing curl..."
sudo apt install curl -y

echo "🧰 Installing NVM & Node.js..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
source ~/.bashrc
. "$HOME/.nvm/nvm.sh"
nvm install 22
nvm use 22

echo "🧾 Installing git..."
sudo apt install git -y

echo "🚀 Installing PM2..."
npm install pm2 -g

echo "📁 Cloning project..."
git clone $REPO_URL
FOLDER_NAME=$(basename "$REPO_URL" .git)

cd $FOLDER_NAME
echo "📦 Installing app dependencies..."
npm install
npm run build

echo "📦 Moving project to /var/www..."
cd ~
sudo mkdir -p /var/www
sudo cp -r $FOLDER_NAME /var/www/

cd /var/www/$FOLDER_NAME

echo "🚀 Starting app with PM2..."
pm2 start npm --name "$APP_NAME" -- start
pm2 save
pm2 startup

echo "🧱 Installing Nginx..."
sudo apt install nginx -y

echo "🔧 Configuring Nginx..."
sudo tee /etc/nginx/sites-available/$APP_NAME > /dev/null <<EOL
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL

sudo ln -s /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
sudo systemctl restart nginx

echo "🔒 Installing Certbot SSL..."
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN

echo "⏰ Setting up SSL auto-renew cron job..."
sudo apt install cron -y
sudo systemctl enable cron
sudo systemctl start cron
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet") | crontab -

echo "✅ Deployment complete!"
