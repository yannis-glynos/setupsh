set -e

echo "Script start"

echo "apt update"
sudo apt update -y
echo "apt upgrade"
sudo apt upgrade -y

echo "Install deps"
sudo apt install -y \
  curl \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common \
  git \
  nginx

echo "install gh"
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
  sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg

sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" | \
  sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

sudo apt update
sudo apt install -y gh

echo "Install docker"

curl -fsSL https://get.docker.com | sh

sudo usermod -aG docker $USER

echo "Install nvm"

export NVM_DIR="$HOME/.nvm"

if [ ! -d "$NVM_DIR" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
fi

source "$NVM_DIR/nvm.sh"

echo "Install node"
nvm install --lts
nvm use --lts
nvm alias default 'lts/*'

echo "Install certbot"
sudo apt install -y certbot python3-certbot-nginx

echo "Installed versions"
docker --version
git --version
gh --version
nginx -v
node -v
npm -v
nvm --version
certbot --version || echo "Certbot installed, but version check failed."

echo ""
echo "You MUST log out and back in or reboot for Docker permissions to apply:"
echo "   sudo reboot"