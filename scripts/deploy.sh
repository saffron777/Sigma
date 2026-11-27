#!/usr/bin/env bash
# Despliega (o actualiza) Sigma en un servidor Linux con Docker.
#
# Uso (en el servidor):
#   curl -fsSL https://raw.githubusercontent.com/saffron777/Sigma/main/scripts/deploy.sh -o deploy.sh
#   sudo SIGMA_DATABASE_URL="mssql+pyodbc://sa:CLAVE@SERVIDOR:1433/Sigma?driver=ODBC+Driver+18+for+SQL+Server&TrustServerCertificate=yes" \
#        SIGMA_ALLOWED_HOSTS="sigma.ejemplo.org" bash deploy.sh
#
# Opcionalmente añade SIGMA_SECURE_COOKIES=1 cuando sirvas por HTTPS.
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/Sigma}"
REPO_URL="${REPO_URL:-https://github.com/saffron777/Sigma.git}"
BRANCH="${BRANCH:-main}"

echo "== 1/5 Docker =="
if command -v docker >/dev/null 2>&1; then
  echo "Docker ya está instalado ($(docker --version))."
elif [ -f /etc/os-release ]; then
  . /etc/os-release
  case "$ID" in
    debian|ubuntu)
      echo "Instalando Docker Engine (Debian/Ubuntu)..."
      apt-get update
      apt-get install -y ca-certificates curl
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL "https://download.docker.com/linux/$ID/gpg" -o /etc/apt/keyrings/docker.asc
      chmod a+r /etc/apt/keyrings/docker.asc
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$ID $VERSION_CODENAME stable" \
        > /etc/apt/sources.list.d/docker.list
      apt-get update
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      ;;
    *)
      echo "Distro «$ID» no reconocida: instala Docker + Compose manualmente y vuelve a ejecutar." >&2
      exit 1
      ;;
  esac
else
  echo "No se pudo detectar la distribución: instala Docker + Compose manualmente y vuelve a ejecutar." >&2
  exit 1
fi

echo "== 2/5 Código =="
if [ -d "$APP_DIR/.git" ]; then
  echo "Actualizando $APP_DIR..."
  git -C "$APP_DIR" fetch origin "$BRANCH"
  git -C "$APP_DIR" checkout "$BRANCH"
  git -C "$APP_DIR" pull --ff-only origin "$BRANCH"
else
  echo "Clonando en $APP_DIR..."
  git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
fi
cd "$APP_DIR"

echo "== 3/5 Configuración (.env) =="
if [ ! -f .env ]; then
  cp .env.example .env
fi
# Inyecta los valores pasados por entorno (sin sobrescribir lo ya escrito)
_add() { grep -q "^$1=" .env || echo "$1=$2" >> .env; }
[ -n "${SIGMA_DATABASE_URL:-}" ] && _add SIGMA_DATABASE_URL "$SIGMA_DATABASE_URL"
[ -n "${SIGMA_ALLOWED_HOSTS:-}" ] && _add SIGMA_ALLOWED_HOSTS "$SIGMA_ALLOWED_HOSTS"
[ -n "${SIGMA_SECURE_COOKIES:-}" ] && _add SIGMA_SECURE_COOKIES "$SIGMA_SECURE_COOKIES"
[ -n "${SIGMA_URL_PREFIX:-}" ] && _add SIGMA_URL_PREFIX "$SIGMA_URL_PREFIX"

echo "== 4/5 Construir y arrancar =="
docker compose up --build -d

echo "== 5/5 Salud =="
for i in $(seq 1 24); do
  if body=$(curl -fsS http://127.0.0.1:5000/health 2>/dev/null); then
    echo "OK: $body"
    break
  fi
  [ "$i" = 24 ] && { echo "El contenedor no respondió en /health. Revisa: docker compose logs -f sigma"; exit 1; }
  sleep 5
done

echo "Sigma disponible en http://127.0.0.1:5000"
echo "Para HTTPS pon delante Caddy o Nginx (docs/DEPLOYMENT.md) y define SIGMA_SECURE_COOKIES=1."
