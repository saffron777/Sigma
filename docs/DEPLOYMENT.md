# Despliegue de Sigma

## Docker (recomendado)

```bash
docker compose up --build -d
```

La aplicación escucha en `127.0.0.1:5000` y guarda sus datos en el volumen
`sigma_instance` (`/app/instance`). Para actualizar:

```bash
docker compose pull
docker compose up -d
```

Si construyes localmente, usa `docker compose build` antes de `up`.

### Variables de entorno

Copia `.env.example` a `.env` y ajusta lo que necesites. Docker Compose lee `.env` para
interpolar las variables del servicio. Las más importantes:

| Variable | Uso |
|---|---|
| `SIGMA_SOURCE_URL` | URL pública del código fuente (se muestra en la interfaz). |
| `SIGMA_SECRET_KEY` | Secreto de sesión. Si se deja vacío, Sigma genera `instance/secret.key`. |
| `SIGMA_DATABASE_URL` | Base de datos externa; vacío usa SQLite en `instance/sigma.db`. |
| `SIGMA_HOST` / `SIGMA_PORT` | Escucha; en Docker se fija `0.0.0.0:5000`. |
| `SIGMA_SECURE_COOKIES` | `1` cuando se sirve por HTTPS. |
| `SIGMA_ALLOWED_HOSTS` | Nombres de host permitidos si se accede por red. |
| `SIGMA_EXTERNAL_DB_HOSTS` | Limita los servidores de bases externas que se pueden importar. |
| `SIGMA_AI_REQUESTS_PER_HOUR` | Límite de interpretaciones con IA por persona y hora. |

No publiques `.env` ni el volumen `instance/`: contienen secretos y datos de usuarios.

## SQL Server

La imagen de Sigma incluye «ODBC Driver 18 for SQL Server», por lo que
`SIGMA_DATABASE_URL=mssql+pyodbc://…` funciona sin pasos adicionales. El servidor debe ser
accesible por red desde el contenedor (un SQL Server local de Windows como `.\sqlexpress`
no lo es). Si el servidor usa un certificado autofirmado, añade `&TrustServerCertificate=yes`
a la URL. Recuerda la licencia: la edición Developer de SQL Server no es válida en producción.

## HTTPS con proxy inverso

No expongas Waitress directamente a Internet. Ejemplo con Caddy:

```caddyfile
sigma.example.org {
    reverse_proxy 127.0.0.1:5000
    encode gzip
}
```

Con Nginx, reenvía a `http://127.0.0.1:5000` y configura TLS (Certbot). En ambos casos:

- fija `SIGMA_SECURE_COOKIES=1`;
- añade el dominio a `SIGMA_ALLOWED_HOSTS` si corresponde;
- revisa el límite de subida (`SIGMA_MAX_UPLOAD_MB`) y el tamaño máximo del cuerpo en el proxy;
- limita quién puede tener permiso de consola (ejecuta código con los permisos del servidor).

## Servir bajo una subruta (p. ej. `/sigma`)

Sigma puede vivir en una subruta, por ejemplo `https://web.ejemplo.org/sigma`. Define
`SIGMA_URL_PREFIX=/sigma` y, en Nginx, reenvía la ruta completa (sin quitar el prefijo):

```nginx
location = /sigma { return 301 /sigma/; }
location /sigma/ {
    proxy_pass http://127.0.0.1:5000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    client_max_body_size 100m;
}
```

Con `SIGMA_URL_PREFIX` vacío Sigma se sirve en la raíz (comportamiento por defecto).

## Copias de seguridad

El estado vive en `instance/` (base SQLite, `secret.key`, `ai.json`, notebooks, importaciones
pendientes) o en la base externa configurada. Para una instalación SQLite, detén el servicio
o usa la copia en caliente de SQLite y guarda todo `instance/` con permisos restringidos.
Prueba periódicamente la restauración.

## Actualizaciones

1. Haz copia de seguridad.
2. `docker compose pull && docker compose up -d` (o reconstruye).
3. Comprueba `/health` y la página `/ayuda#acerca`.
4. Las migraciones de esquema se ejecutan al arrancar; revisa los mensajes del contenedor.

Si usas una base externa, el administrador puede cambiar de motor desde **Base de datos**;
haz copia antes de migrar y reinicia los procesos de Sigma que estén en ejecución.
