#!/usr/bin/env bash

set -e

echo "Project Initializer"

ask_yes_no() {
  local prompt="$1"
  local default="${2:-y}"
  local answer

  while true; do
    if [ "$default" = "y" ]; then
      read -rp "$prompt [Y/n]: " answer
      answer="${answer:-y}"
    else
      read -rp "$prompt [y/N]: " answer
      answer="${answer:-n}"
    fi

    case "$answer" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

sanitize_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g'
}

# ---------- Ask for project type & name ----------

echo "Select project type:"
echo "  1) Vite app"
echo "  2) Node.js app"
echo "  3) WordPress (Docker)"
read -rp "Enter choice [1-3]: " PROJECT_TYPE_CHOICE

case "$PROJECT_TYPE_CHOICE" in
  1) PROJECT_TYPE="vite" ;;
  2) PROJECT_TYPE="node" ;;
  3) PROJECT_TYPE="wordpress" ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

read -rp "Enter project name: " PROJECT_NAME_RAW
if [ -z "$PROJECT_NAME_RAW" ]; then
  echo "Project name cannot be empty."
  exit 1
fi

PROJECT_NAME="$(sanitize_name "$PROJECT_NAME_RAW")"
echo "Project folder will be: $PROJECT_NAME"
mkdir -p "$PROJECT_NAME"
cd "$PROJECT_NAME"

echo "========================================"
echo "Creating $PROJECT_TYPE project: $PROJECT_NAME"
echo "========================================"

# ---------- Vite Project ----------

create_vite_project() {
  echo "Initializing Vite app (React + JS)..."
  npm create vite@latest . -- --template react || {
    echo "Failed to initialize Vite. Make sure npm is installed."
    exit 1
  }

  if ask_yes_no "Would you like to create a .env file for this Vite app?"; then
    read -rp "Vite app title [${PROJECT_NAME_RAW}]: " VITE_APP_TITLE
    VITE_APP_TITLE=${VITE_APP_TITLE:-$PROJECT_NAME_RAW}

    read -rp "API base URL [http://localhost:3000/api]: " VITE_API_BASE_URL
    VITE_API_BASE_URL=${VITE_API_BASE_URL:-http://localhost:3000/api}

    read -rp "Frontend port [5173]: " VITE_PORT
    VITE_PORT=${VITE_PORT:-5173}

    cat > .env <<EOF
VITE_APP_TITLE="$VITE_APP_TITLE"
VITE_API_BASE_URL="$VITE_API_BASE_URL"
VITE_APP_ENV="development"
VITE_APP_PORT=$VITE_PORT
EOF

    echo ".env created for Vite app."
  else
    echo "Skipping .env creation for Vite."
  fi

  echo "Done. You can now:"
  echo "  cd $PROJECT_NAME"
  echo "  npm install"
  echo "  npm run dev"
}

# ---------- Node.js Project ----------

create_node_project() {
  echo "Initializing Node.js app..."

  # Basic package.json
  npm init -y >/dev/null 2>&1 || echo "npm init failed or npm not installed; continuing with manual package.json."

  if [ ! -f package.json ]; then
    cat > package.json <<EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "main": "index.js",
  "type": "module",
  "scripts": {
    "start": "node index.js"
  }
}
EOF
  fi

  # Basic index.js
  if [ ! -f index.js ]; then
    cat > index.js <<'EOF'
import http from "http";

const PORT = process.env.APP_PORT || 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ status: "ok", message: "Hello from Node server" }));
});

server.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
EOF
  fi

  echo "Select database for Node.js app:"
  echo "  1) PostgreSQL"
  echo "  2) MariaDB/MySQL"
  read -rp "Enter choice [1-2]: " DB_CHOICE

  case "$DB_CHOICE" in
    1)
      DB_TYPE="postgres"
      DB_CLIENT="pg"
      DB_PORT_DEFAULT=5432
      ;;
    2)
      DB_TYPE="mariadb"
      DB_CLIENT="mysql2"
      DB_PORT_DEFAULT=3306
      ;;
    *)
      echo "Invalid DB choice. Exiting."
      exit 1
      ;;
  esac

  ADD_ADMIN_TOOL=false
  if ask_yes_no "Would you like to add a database admin tool (pgAdmin/phpMyAdmin)?"; then
    ADD_ADMIN_TOOL=true
  fi

  CREATE_ENV=false
  if ask_yes_no "Would you like to create a .env file for this Node.js app?"; then
    CREATE_ENV=true
  fi

  if [ "$CREATE_ENV" = true ]; then
    echo "Creating .env for Node.js + $DB_TYPE ..."

    read -rp "Node app port [3000]: " APP_PORT
    APP_PORT=${APP_PORT:-3000}

    DB_HOST="db"
    read -rp "Database name [${PROJECT_NAME}_db]: " DB_NAME
    DB_NAME=${DB_NAME:-${PROJECT_NAME}_db}

    read -rp "Database user [app_user]: " DB_USER
    DB_USER=${DB_USER:-app_user}

    read -rsp "Database password [app_password]: " DB_PASSWORD
    echo
    DB_PASSWORD=${DB_PASSWORD:-app_password}

    DB_PORT="$DB_PORT_DEFAULT"

    if [ "$DB_TYPE" = "mariadb" ]; then
      read -rsp "Database root password [root_password]: " DB_ROOT_PASSWORD
      echo
      DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-root_password}
    fi

    # Optional admin creds for pgAdmin
    if [ "$DB_TYPE" = "postgres" ] && [ "$ADD_ADMIN_TOOL" = true ]; then
      read -rp "pgAdmin email [admin@example.com]: " PGADMIN_EMAIL
      PGADMIN_EMAIL=${PGADMIN_EMAIL:-admin@example.com}

      read -rsp "pgAdmin password [pgadmin_password]: " PGADMIN_PASSWORD
      echo
      PGADMIN_PASSWORD=${PGADMIN_PASSWORD:-pgadmin_password}
    fi

    cat > .env <<EOF
NODE_ENV=development
APP_PORT=$APP_PORT

DB_CLIENT=$DB_CLIENT
DB_TYPE=$DB_TYPE
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
EOF

    if [ "$DB_TYPE" = "mariadb" ]; then
cat >> .env <<EOF
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD
EOF
    fi

    if [ "$DB_TYPE" = "postgres" ] && [ "$ADD_ADMIN_TOOL" = true ]; then
cat >> .env <<EOF
PGADMIN_DEFAULT_EMAIL=$PGADMIN_EMAIL
PGADMIN_DEFAULT_PASSWORD=$PGADMIN_PASSWORD
PGADMIN_PORT=8080
EOF
    fi

    echo ".env created for Node.js app."
  else
    echo "Skipping .env creation for Node.js. docker-compose.yml will still reference env vars."
  fi

  echo "Creating Dockerfile for Node.js..."

  cat > Dockerfile <<'EOF'
FROM node:20-alpine

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install || true

COPY . .

CMD ["npm", "start"]
EOF

  echo "Creating docker-compose.yml for Node.js..."

  if [ "$DB_TYPE" = "postgres" ]; then
    cat > docker-compose.yml <<'EOF'
version: "3.8"

services:
  app:
    build: .
    container_name: node_app
    ports:
      - "${APP_PORT:-3000}:3000"
    environment:
      - NODE_ENV=${NODE_ENV}
    depends_on:
      - db
    volumes:
      - .:/usr/src/app

  db:
    image: postgres:16
    container_name: node_db
    environment:
      - POSTGRES_DB=${DB_NAME}
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    ports:
      - "${DB_PORT:-5432}:5432"
    volumes:
      - db_data:/var/lib/postgresql/data

  pgadmin:
    image: dpage/pgadmin4
    container_name: node_pgadmin
    ports:
      - "${PGADMIN_PORT:-8080}:80"
    environment:
      - PGADMIN_DEFAULT_EMAIL=${PGADMIN_DEFAULT_EMAIL}
      - PGADMIN_DEFAULT_PASSWORD=${PGADMIN_DEFAULT_PASSWORD}
    depends_on:
      - db
    # Comment out this whole service if you don't want pgAdmin

volumes:
  db_data:
EOF

    if [ "$ADD_ADMIN_TOOL" = false ]; then
      echo "Note: pgAdmin service is included in docker-compose.yml."
      echo "If you don't want it, comment out or remove the 'pgadmin' service."
    fi

  else
    # MariaDB/MySQL
    cat > docker-compose.yml <<'EOF'
version: "3.8"

services:
  app:
    build: .
    container_name: node_app
    ports:
      - "${APP_PORT:-3000}:3000"
    environment:
      - NODE_ENV=${NODE_ENV}
    depends_on:
      - db
    volumes:
      - .:/usr/src/app

  db:
    image: mariadb:10.6
    container_name: node_db
    environment:
      - MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
      - MYSQL_DATABASE=${DB_NAME}
      - MYSQL_USER=${DB_USER}
      - MYSQL_PASSWORD=${DB_PASSWORD}
    ports:
      - "${DB_PORT:-3306}:3306"
    volumes:
      - db_data:/var/lib/mysql

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    container_name: node_phpmyadmin
    ports:
      - "${PHPMYADMIN_PORT:-8081}:80"
    environment:
      - PMA_HOST=db
      - PMA_USER=${DB_USER}
      - PMA_PASSWORD=${DB_PASSWORD}
    depends_on:
      - db
    # Comment out this whole service if you don't want phpMyAdmin

volumes:
  db_data:
EOF

    if [ "$ADD_ADMIN_TOOL" = false ]; then
      echo "Note: phpMyAdmin service is included in docker-compose.yml."
      echo "If you don't want it, comment out or remove the 'phpmyadmin' service."
    fi
  fi

  echo "Node.js project initialized with Docker and database config placeholders."
}

# ---------- WordPress Project ----------

create_wordpress_project() {
  echo "Initializing WordPress (Dockerized)..."

  echo "Select database for WordPress:"
  echo "  1) PostgreSQL"
  echo "  2) MariaDB/MySQL"
  read -rp "Enter choice [1-2]: " DB_CHOICE

  case "$DB_CHOICE" in
    1)
      DB_TYPE="postgres"
      DB_PORT_DEFAULT=5432
      ;;
    2)
      DB_TYPE="mariadb"
      DB_PORT_DEFAULT=3306
      ;;
    *)
      echo "Invalid DB choice. Exiting."
      exit 1
      ;;
  esac

  ADD_ADMIN_TOOL=false
  if ask_yes_no "Would you like to add a database admin tool (pgAdmin/phpMyAdmin)?"; then
    ADD_ADMIN_TOOL=true
  fi

  CREATE_ENV=false
  if ask_yes_no "Would you like to create a .env file for this WordPress setup?"; then
    CREATE_ENV=true
  fi

  if [ "$CREATE_ENV" = true ]; then
    echo "Creating .env for WordPress + $DB_TYPE ..."

    read -rp "WordPress HTTP port [8000]: " WP_PORT
    WP_PORT=${WP_PORT:-8000}

    DB_HOST="db"
    read -rp "Database name [wordpress]: " DB_NAME
    DB_NAME=${DB_NAME:-wordpress}

    read -rp "Database user [wp_user]: " DB_USER
    DB_USER=${DB_USER:-wp_user}

    read -rsp "Database password [wp_password]: " DB_PASSWORD
    echo
    DB_PASSWORD=${DB_PASSWORD:-wp_password}

    DB_PORT="$DB_PORT_DEFAULT"

    if [ "$DB_TYPE" = "mariadb" ]; then
      read -rsp "Database root password [root_password]: " DB_ROOT_PASSWORD
      echo
      DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-root_password}
    fi

    if [ "$DB_TYPE" = "postgres" ] && [ "$ADD_ADMIN_TOOL" = true ]; then
      read -rp "pgAdmin email [admin@example.com]: " PGADMIN_EMAIL
      PGADMIN_EMAIL=${PGADMIN_EMAIL:-admin@example.com}

      read -rsp "pgAdmin password [pgadmin_password]: " PGADMIN_PASSWORD
      echo
      PGADMIN_PASSWORD=${PGADMIN_PASSWORD:-pgadmin_password}
    fi

    if [ "$DB_TYPE" = "mariadb" ] && [ "$ADD_ADMIN_TOOL" = true ]; then
      read -rp "phpMyAdmin HTTP port [8081]: " PHPMYADMIN_PORT
      PHPMYADMIN_PORT=${PHPMYADMIN_PORT:-8081}
    fi

    read -rp "Site URL [http://localhost:$WP_PORT]: " SITE_URL
    SITE_URL=${SITE_URL:-http://localhost:$WP_PORT}

    read -rp "Site title [${PROJECT_NAME_RAW}]: " SITE_TITLE
    SITE_TITLE=${SITE_TITLE:-$PROJECT_NAME_RAW}

    read -rp "Admin email [admin@example.com]: " ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}

    cat > .env <<EOF
# WordPress app
WP_PORT=$WP_PORT
SITE_URL=$SITE_URL
SITE_TITLE="$SITE_TITLE"
ADMIN_EMAIL=$ADMIN_EMAIL

# Database common
DB_TYPE=$DB_TYPE
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
EOF

    if [ "$DB_TYPE" = "mariadb" ]; then
cat >> .env <<EOF
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD
EOF
    fi

    if [ "$DB_TYPE" = "postgres" ] && [ "$ADD_ADMIN_TOOL" = true ]; then
cat >> .env <<EOF
PGADMIN_DEFAULT_EMAIL=$PGADMIN_EMAIL
PGADMIN_DEFAULT_PASSWORD=$PGADMIN_PASSWORD
PGADMIN_PORT=8080
EOF
    fi

    if [ "$DB_TYPE" = "mariadb" ] && [ "$ADD_ADMIN_TOOL" = true ]; then
cat >> .env <<EOF
PHPMYADMIN_PORT=$PHPMYADMIN_PORT
EOF
    fi

    # WordPress-specific DB vars
cat >> .env <<EOF
WORDPRESS_DB_HOST=db
WORDPRESS_DB_NAME=$DB_NAME
WORDPRESS_DB_USER=$DB_USER
WORDPRESS_DB_PASSWORD=$DB_PASSWORD
WORDPRESS_TABLE_PREFIX=wp_
WORDPRESS_DEBUG=true
EOF

    echo ".env created for WordPress."
  else
    echo "Skipping .env creation for WordPress. docker-compose.yml will still reference env vars."
  fi

  echo "Creating docker-compose.yml for WordPress..."

  if [ "$DB_TYPE" = "postgres" ]; then
    cat > docker-compose.yml <<'EOF'
version: "3.8"

services:
  wordpress:
    image: wordpress:latest
    container_name: wp_app
    ports:
      - "${WP_PORT:-8000}:80"
    environment:
      - WORDPRESS_DB_HOST=${WORDPRESS_DB_HOST}
      - WORDPRESS_DB_USER=${WORDPRESS_DB_USER}
      - WORDPRESS_DB_PASSWORD=${WORDPRESS_DB_PASSWORD}
      - WORDPRESS_DB_NAME=${WORDPRESS_DB_NAME}
      - WORDPRESS_TABLE_PREFIX=${WORDPRESS_TABLE_PREFIX}
      - WORDPRESS_DEBUG=${WORDPRESS_DEBUG}
    depends_on:
      - db
    volumes:
      - ./wp-content:/var/www/html/wp-content

  db:
    image: postgres:16
    container_name: wp_db
    environment:
      - POSTGRES_DB=${DB_NAME}
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    ports:
      - "${DB_PORT:-5432}:5432"
    volumes:
      - db_data:/var/lib/postgresql/data

  pgadmin:
    image: dpage/pgadmin4
    container_name: wp_pgadmin
    ports:
      - "${PGADMIN_PORT:-8080}:80"
    environment:
      - PGADMIN_DEFAULT_EMAIL=${PGADMIN_DEFAULT_EMAIL}
      - PGADMIN_DEFAULT_PASSWORD=${PGADMIN_DEFAULT_PASSWORD}
    depends_on:
      - db
    # Comment out this whole service if you don't want pgAdmin

volumes:
  db_data:
EOF

    if [ "$ADD_ADMIN_TOOL" = false ]; then
      echo "Note: pgAdmin service is included in docker-compose.yml."
      echo "If you don't want it, comment out or remove the 'pgadmin' service."
    fi

  else
    # MariaDB/MySQL
    cat > docker-compose.yml <<'EOF'
version: "3.8"

services:
  wordpress:
    image: wordpress:latest
    container_name: wp_app
    ports:
      - "${WP_PORT:-8000}:80"
    environment:
      - WORDPRESS_DB_HOST=${WORDPRESS_DB_HOST}
      - WORDPRESS_DB_USER=${WORDPRESS_DB_USER}
      - WORDPRESS_DB_PASSWORD=${WORDPRESS_DB_PASSWORD}
      - WORDPRESS_DB_NAME=${WORDPRESS_DB_NAME}
      - WORDPRESS_TABLE_PREFIX=${WORDPRESS_TABLE_PREFIX}
      - WORDPRESS_DEBUG=${WORDPRESS_DEBUG}
    depends_on:
      - db
    volumes:
      - ./wp-content:/var/www/html/wp-content

  db:
    image: mariadb:10.6
    container_name: wp_db
    environment:
      - MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
      - MYSQL_DATABASE=${DB_NAME}
      - MYSQL_USER=${DB_USER}
      - MYSQL_PASSWORD=${DB_PASSWORD}
    ports:
      - "${DB_PORT:-3306}:3306"
    volumes:
      - db_data:/var/lib/mysql

  phpmyadmin:
    image: phpmyadmin/phpmyadmin
    container_name: wp_phpmyadmin
    ports:
      - "${PHPMYADMIN_PORT:-8081}:80"
    environment:
      - PMA_HOST=db
      - PMA_USER=${DB_USER}
      - PMA_PASSWORD=${DB_PASSWORD}
    depends_on:
      - db
    # Comment out this whole service if you don't want phpMyAdmin

volumes:
  db_data:
EOF

    if [ "$ADD_ADMIN_TOOL" = false ]; then
      echo "Note: phpMyAdmin service is included in docker-compose.yml."
      echo "If you don't want it, comment out or remove the 'phpmyadmin' service."
    fi
  fi

  echo "WordPress project initialized with Docker, DB, and optional admin tool."
}

# ---------- Dispatcher ----------

case "$PROJECT_TYPE" in
  vite)       create_vite_project ;;
  node)       create_node_project ;;
  wordpress)  create_wordpress_project ;;
esac

echo "All done! Project created in: $PROJECT_NAME"
