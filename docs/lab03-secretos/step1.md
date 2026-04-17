---
tags:
  - lab
  - gitleaks
  - secretos
---

# Paso 1 -- Gitleaks Local

!!! abstract "Objetivo"
    Instalar Gitleaks en tu maquina local, escanear la carpeta `vulnerable-app/` y analizar los secretos encontrados en `.env.example`, `users.py`, `Dockerfile` y `app.py`.

## 1.1 Instalar Gitleaks

=== "macOS (Homebrew)"

    ```bash title="Terminal"
    brew install gitleaks
    ```

=== "Linux"

    ```bash title="Terminal"
    # Descargar la ultima version
    GITLEAKS_VERSION=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep tag_name | cut -d '"' -f 4)
    wget https://github.com/gitleaks/gitleaks/releases/download/${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION#v}_linux_x64.tar.gz
    tar -xzf gitleaks_${GITLEAKS_VERSION#v}_linux_x64.tar.gz
    sudo mv gitleaks /usr/local/bin/
    ```

=== "Docker"

    ```bash title="Terminal"
    # No necesitas instalar nada, usaremos la imagen directamente
    docker pull ghcr.io/gitleaks/gitleaks:latest
    ```

Verifica la instalacion:

```bash title="Terminal"
gitleaks version
```

## 1.2 Escanear vulnerable-app/ (modo directorio)

Ejecuta un escaneo sobre el directorio `vulnerable-app/`:

```bash title="Terminal"
# Escaneo de directorio (sin historial git)
gitleaks detect --source vulnerable-app/ --no-git --verbose
```

!!! tip "Modos de escaneo"
    - `--no-git` -- Escanea solo archivos actuales (no historial de git)
    - Sin `--no-git` -- Escanea el historial completo de commits
    - `--verbose` -- Muestra cada hallazgo con detalle

### Salida esperada

Gitleaks deberia encontrar multiples secretos. La salida sera similar a:

```text title="Salida de Gitleaks"
Finding:     AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
Secret:      AKIAIOSFODNN7EXAMPLE
RuleID:      aws-access-token
Entropy:     3.684184
File:        vulnerable-app/.env.example
Line:        3
Fingerprint: vulnerable-app/.env.example:aws-access-token:3

Finding:     AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Secret:      wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
RuleID:      aws-secret-access-key
Entropy:     4.721928
File:        vulnerable-app/.env.example
Line:        4
Fingerprint: vulnerable-app/.env.example:aws-secret-access-key:4

Finding:     ADMIN_API_KEY = "sk-entelgy-4f8a2b1c9d3e7f6a0b5c8d2e1f4a7b3c"
Secret:      sk-entelgy-4f8a2b1c9d3e7f6a0b5c8d2e1f4a7b3c
RuleID:      generic-api-key
Entropy:     4.295281
File:        vulnerable-app/src/api/users.py
Line:        4
Fingerprint: vulnerable-app/src/api/users.py:generic-api-key:4

Finding:     DATABASE_PASSWORD=Entelgy2024!Prod
Secret:      Entelgy2024!Prod
RuleID:      generic-password
Entropy:     3.321928
File:        vulnerable-app/Dockerfile
Line:        16
Fingerprint: vulnerable-app/Dockerfile:generic-password:16

...

12 findings detected. Gitleaks exited with code 1.
```

## 1.3 Interpretar los hallazgos

Analicemos los hallazgos encontrados:

### Archivo: `vulnerable-app/.env.example`

| Hallazgo | Regla | Riesgo |
|----------|-------|--------|
| `AKIAIOSFODNN7EXAMPLE` | `aws-access-token` | Acceso completo a recursos AWS |
| `wJalrXUtnFEMI/K7MDENG/...` | `aws-secret-access-key` | Par de credenciales AWS completo |
| `postgresql://admin:Entelgy2024!Prod@...` | `generic-password` | Acceso directo a base de datos |
| `entelgy_7f8a2b1c9d3e4f5a6b7c8d9e...` | `generic-api-key` | Azure Client Secret |
| `https://hooks.slack.com/services/...` | `slack-webhook` | Enviar mensajes a canales de Slack |

### Archivo: `vulnerable-app/src/api/users.py`

| Hallazgo | Regla | Riesgo |
|----------|-------|--------|
| `sk-entelgy-4f8a2b1c9d3e7f6a...` | `generic-api-key` | Acceso administrativo a la API |
| `db_password=Entelgy2024!Prod` | `generic-password` | Credenciales de base de datos |

### Archivo: `vulnerable-app/Dockerfile`

| Hallazgo | Regla | Riesgo |
|----------|-------|--------|
| `DATABASE_PASSWORD=Entelgy2024!Prod` | `generic-password` | Contraseña expuesta en capas de la imagen |

!!! warning "Secretos en Dockerfiles"
    Los secretos en variables `ENV` de un Dockerfile quedan **permanentemente** en las capas de la imagen. Cualquiera con acceso a la imagen puede extraerlos con `docker history` o `docker inspect`.

## 1.4 Generar reporte SARIF

Genera un reporte en formato SARIF (Static Analysis Results Interchange Format) que es el estandar para resultados de analisis de seguridad:

```bash title="Terminal"
gitleaks detect \
  --source vulnerable-app/ \
  --no-git \
  --report-format sarif \
  --report-path gitleaks-report.sarif
```

Inspecciona el contenido:

```bash title="Terminal"
# Ver el reporte generado (JSON)
cat gitleaks-report.sarif | python3 -m json.tool | head -50
```

!!! info "Formato SARIF"
    SARIF es un formato JSON estandar (OASIS) para reportar resultados de herramientas de analisis estatico. Es compatible con GitHub Code Scanning, Azure DevOps y muchas otras plataformas. Lo usaremos en varios labs para publicar artefactos.

## 1.5 Escaneo con configuracion personalizada

El repositorio incluye una configuracion personalizada en `vulnerable-app/.gitleaks.toml`. Examina su contenido:

```toml title="vulnerable-app/.gitleaks.toml"
[extend]
useDefault = true

[[rules]]
id = "entelgy-internal-key"
description = "Entelgy Internal API Key"
regex = '''entelgy_[a-zA-Z0-9]{32,}'''
tags = ["api-key", "entelgy"]

[[rules]]
id = "azure-client-secret"
description = "Azure Client Secret with entelgy prefix"
regex = '''entelgy_[a-f0-9]{32,}'''
tags = ["azure", "credential"]

[allowlist]
description = "Allowlist for tests and examples"
paths = [
    '''tests/fixtures/.*''',
    '''docs/.*''',
]
```

Ejecuta con esta configuracion:

```bash title="Terminal"
gitleaks detect \
  --source vulnerable-app/ \
  --no-git \
  --config vulnerable-app/.gitleaks.toml \
  --verbose
```

!!! tip "Reglas personalizadas"
    La configuracion define dos reglas adicionales especificas para detectar claves internas de Entelgy (`entelgy_...`). Tambien incluye un `allowlist` que excluye directorios como `tests/fixtures/` y `docs/` donde puede haber ejemplos inofensivos.

## 1.6 Resumen de hallazgos

En total, Gitleaks deberia encontrar los siguientes tipos de secretos:

```mermaid
pie title Secretos por tipo
    "AWS Credentials" : 2
    "API Keys" : 2
    "Passwords/DB" : 3
    "Webhooks" : 1
    "Azure Secrets" : 1
```

Todos estos secretos representan riesgos reales que un atacante podria explotar. En el siguiente paso, automatizaremos esta deteccion en el pipeline.

!!! success "Paso Completado"
    Has ejecutado Gitleaks localmente y encontrado multiples secretos en `vulnerable-app/`. Ahora entiendes que tipos de secretos detecta y como interpretar la salida.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../" class="md-button">Volver al Lab 3</a>
  <a href="../step2/" class="md-button md-button--primary">Paso 2: Añadir Stage al Pipeline</a>
</div>
