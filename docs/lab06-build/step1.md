---
tags:
  - lab
  - docker
  - hadolint
  - hardening
---

# Paso 1 -- Hardening del Dockerfile

!!! abstract "Objetivo"
    Revisar el Dockerfile inseguro de `vulnerable-app/`, ejecutar Hadolint para identificar malas practicas, y corregir cada problema usando `Dockerfile.secure` como referencia.

## 1.1 Revisar el Dockerfile inseguro

Examina el Dockerfile actual de `vulnerable-app/`:

```dockerfile title="vulnerable-app/Dockerfile"
# VULNERABLE Dockerfile — used as the "before" example in Lab 6
FROM python:latest

USER root

COPY . /app
WORKDIR /app

RUN pip install -r requirements.txt

RUN apt-get update && apt-get install -y curl vim wget netcat-openbsd

EXPOSE 22 8080

ENV FLASK_ENV=development
ENV DATABASE_PASSWORD=Entelgy2024!Prod

CMD ["python", "app.py"]
```

!!! warning "Problemas visibles a simple vista"
    Incluso sin herramientas, un ojo entrenado puede identificar multiples problemas:

    1. `python:latest` -- Imagen no fijada
    2. `USER root` -- Ejecuta como root
    3. `COPY . /app` -- Copia todo, incluyendo `.env.example` y `.git/`
    4. `pip install` sin `--no-cache-dir`
    5. Herramientas innecesarias (`vim`, `wget`, `netcat`)
    6. Puerto 22 (SSH) expuesto
    7. `FLASK_ENV=development` en produccion
    8. Contraseña en `ENV`

## 1.2 Instalar y ejecutar Hadolint

Hadolint es un linter para Dockerfiles que detecta malas practicas y violaciones de seguridad.

=== "macOS (Homebrew)"

    ```bash title="Terminal"
    brew install hadolint
    ```

=== "Docker"

    ```bash title="Terminal"
    docker pull hadolint/hadolint:latest
    ```

Ejecuta Hadolint contra el Dockerfile inseguro:

```bash title="Terminal"
hadolint vulnerable-app/Dockerfile
```

### Salida esperada

```text title="Salida de Hadolint"
vulnerable-app/Dockerfile:2 DL3007 warning: Using latest is prone to errors if the image will
  ever update. Pin the version explicitly to a release tag
vulnerable-app/Dockerfile:2 DL3006 warning: Always tag the version of an image explicitly
vulnerable-app/Dockerfile:6 DL3045 warning: `COPY` to a relative destination without setting
  `WORKDIR` first
vulnerable-app/Dockerfile:9 DL3042 warning: Avoid use of cache directory with pip. Use
  `pip install --no-cache-dir <package>`
vulnerable-app/Dockerfile:11 DL3008 warning: Pin versions in apt-get install. Instead of
  `apt-get install -y curl` use `apt-get install -y curl=<version>`
vulnerable-app/Dockerfile:11 DL3009 info: Delete the apt-get lists after installing something
vulnerable-app/Dockerfile:11 DL3015 info: Avoid additional packages by specifying
  `--no-install-recommends`
vulnerable-app/Dockerfile:13 DL3011 error: Valid UNIX ports range from 0 to 65535
```

## 1.3 Tabla de problemas encontrados

| Regla | Severidad | Linea | Problema | Riesgo de seguridad |
|-------|-----------|-------|----------|-------------------|
| DL3007 | warning | 2 | `FROM python:latest` | Imagen impredecible, puede incluir CVEs nuevas |
| DL3006 | warning | 2 | Imagen sin tag | Sin reproducibilidad |
| DL3045 | warning | 6 | COPY sin WORKDIR previo | Rutas impredecibles |
| DL3042 | warning | 9 | pip sin `--no-cache-dir` | Imagen mas grande de lo necesario |
| DL3008 | warning | 11 | apt-get sin versiones | Paquetes impredecibles |
| DL3009 | info | 11 | apt-get lists no borradas | Imagen inflada |
| DL3015 | info | 11 | Sin `--no-install-recommends` | Paquetes extra innecesarios |
| *(custom)* | **error** | 4 | `USER root` | Ejecucion con privilegios maximos |
| *(custom)* | **error** | 15 | Secreto en `ENV` | Credencial en capas de imagen |
| *(custom)* | **error** | 13 | Puerto 22 expuesto | SSH en contenedor |

!!! tip "Hadolint no lo detecta todo"
    Hadolint se centra en la sintaxis y buenas practicas del Dockerfile. No analiza:

    - Secretos hardcodeados en `ENV` (necesitas Gitleaks/Semgrep para eso)
    - Vulnerabilidades en la imagen base (necesitas Trivy image)
    - Logica de la aplicacion

## 1.4 Comparar con el Dockerfile seguro

Ahora examina `Dockerfile.secure`, que es la version corregida:

```dockerfile title="vulnerable-app/Dockerfile.secure"
# SECURE Dockerfile — revealed in Lab 6 Step 1
FROM python:3.11-slim-bookworm

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY app.py .

RUN addgroup --system app && adduser --system --group app
USER app

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"

CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:8080", "--workers", "2"]
```

## 1.5 Mejoras aplicadas (comparacion detallada)

| Aspecto | Dockerfile inseguro | Dockerfile.secure | Por que |
|---------|-------------------|-------------------|---------|
| **Imagen base** | `python:latest` | `python:3.11-slim-bookworm` | Version fija, imagen minimal |
| **Usuario** | `root` | `app` (non-root) | Principio de minimo privilegio |
| **COPY** | `COPY . /app` (todo) | `COPY requirements.txt .` + `COPY src/ ./src/` | Solo lo necesario |
| **pip** | `pip install` | `pip install --no-cache-dir` | Imagen mas pequeña |
| **apt-get** | Sin limpieza | `apt-get clean && rm -rf /var/lib/apt/lists/*` | Imagen mas pequeña |
| **Paquetes** | `curl vim wget netcat` | Solo `libpq-dev` | Superficie de ataque minima |
| **Puertos** | `22 8080` | Solo `8080` | Sin SSH |
| **Secretos** | `ENV DATABASE_PASSWORD=...` | No hay secretos | Usar runtime secrets |
| **Entorno** | `FLASK_ENV=development` | No configurado | Produccion por defecto |
| **Runtime** | `python app.py` | `gunicorn` con workers | Servidor de produccion |
| **Health** | No tiene | `HEALTHCHECK` definido | Orquestadores pueden verificar salud |

!!! info "Slim vs Alpine"
    Usamos `python:3.11-slim-bookworm` en lugar de `python:3.11-alpine` porque Alpine usa `musl` en lugar de `glibc`, lo que puede causar problemas con paquetes como `cryptography` que dependen de extensiones C. Slim es un buen balance entre tamaño y compatibilidad.

## 1.6 Ejecutar Hadolint contra el Dockerfile seguro

```bash title="Terminal"
hadolint vulnerable-app/Dockerfile.secure
```

La salida deberia estar limpia o con solo avisos informativos menores.

## 1.7 Construir la imagen localmente

Construye la imagen usando el Dockerfile seguro:

```bash title="Terminal"
cd vulnerable-app

# Construir con el Dockerfile seguro
docker build -f Dockerfile.secure -t vulnerable-app:local-test .

# Verificar la imagen
docker images vulnerable-app:local-test

# Inspeccionar capas
docker history vulnerable-app:local-test

# Verificar que corre como non-root
docker run --rm vulnerable-app:local-test whoami
# Deberia mostrar: app
```

Compara el tamaño de las dos imagenes:

```bash title="Terminal"
# Construir ambas para comparar
docker build -f Dockerfile -t vulnerable-app:insecure .
docker build -f Dockerfile.secure -t vulnerable-app:secure .

# Comparar tamaños
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep vulnerable-app
```

La imagen segura deberia ser significativamente mas pequeña (slim + sin herramientas extra).

## 1.8 Verificar que no hay secretos en las capas

```bash title="Terminal"
# Buscar secretos en el historial de capas de la imagen insegura
docker history vulnerable-app:insecure --no-trunc | grep -i password
# Resultado: ENV DATABASE_PASSWORD=Entelgy2024!Prod  <-- VISIBLE!

# Verificar que la imagen segura no tiene secretos
docker history vulnerable-app:secure --no-trunc | grep -i password
# Resultado: (nada)
```

!!! warning "Capas de imagen y secretos"
    Aunque borres un secreto en una capa posterior con `RUN rm /app/.env`, el secreto sigue existiendo en la capa anterior. Docker guarda cada capa como una diff. **Nunca** pongas secretos en el Dockerfile; usa variables de entorno en runtime o Docker secrets.

!!! success "Paso Completado"
    Has analizado el Dockerfile inseguro con Hadolint, comparado con la version segura, y construido la imagen localmente verificando que no contiene secretos en sus capas.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../" class="md-button">Volver al Lab 6</a>
  <a href="../step2/" class="md-button md-button--primary">Paso 2: Stage de Build + GHCR</a>
</div>
