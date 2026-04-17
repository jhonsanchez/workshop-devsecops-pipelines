---
tags:
  - lab
  - gitleaks
  - remediacion
  - secretos
---

# Paso 3 -- Probar y Remediar

!!! abstract "Objetivo"
    Plantar un secreto de prueba en una rama, verificar que el pipeline lo detecta, y practicar el flujo completo de remediacion: revocar, rotar y reescribir el historial de git.

## 3.1 Crear una rama de prueba

Vamos a simular un escenario real: un desarrollador introduce accidentalmente un secreto en el codigo.

```bash title="Terminal"
git checkout -b feature/test-secret-detection
```

## 3.2 Plantar un secreto de prueba

Crea un archivo temporal con un secreto falso:

```bash title="Terminal"
cat > vulnerable-app/config_temp.py << 'EOF'
# Archivo temporal de configuracion
# ATENCION: Este archivo se usa solo para probar la deteccion de secretos

DATABASE_URL = "postgresql://admin:SuperSecretPassword123!@prod-db.entelgy.internal:5432/production"
STRIPE_SECRET_KEY = "sk_live_EJEMPLO_NO_REAL_CLAVE_DE_PRUEBA"
GITHUB_TOKEN = "ghp_EJEMPLO_NO_REAL_TOKEN_FICTICIO_00"
SENDGRID_API_KEY = "SG.xxxxxxxxxxxxxxxxxxxxxxxxxx.yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"
EOF
```

```bash title="Terminal"
git add vulnerable-app/config_temp.py
git commit -m "feat: agregar configuracion de produccion"
git push origin feature/test-secret-detection
```

!!! warning "Secretos de prueba"
    Los secretos plantados arriba son **falsos** (no funcionan). En un escenario real, cualquier secreto que se haya commiteado, aunque sea por error, debe ser tratado como comprometido.

## 3.3 Verificar que el pipeline lo detecta

Si tu pipeline tiene trigger para todas las ramas (o puedes ejecutarlo manualmente):

1. Ve a Azure DevOps > **Pipelines**
2. Haz clic en **Run pipeline**
3. Selecciona la rama `feature/test-secret-detection`
4. Haz clic en **Run**

El stage SecretsDetection deberia fallar con hallazgos adicionales para:

- `sk_live_...` (Stripe Secret Key)
- `ghp_...` (GitHub Personal Access Token)
- `SG....` (SendGrid API Key)
- Credenciales de PostgreSQL

Verifica los logs y el artefacto SARIF para confirmar que todos fueron detectados.

!!! success "Paso Completado"
    El pipeline detecto correctamente los secretos plantados. Ahora vamos a practicar la remediacion.

## 3.4 Flujo de remediacion

Cuando se detecta un secreto en un repositorio, el flujo de remediacion tiene **tres pasos obligatorios**:

```mermaid
graph LR
    A[1. Revocar] --> B[2. Rotar]
    B --> C[3. Limpiar historial]
    C --> D[4. Verificar]
```

### Paso 1: Revocar el secreto

**Inmediatamente** revoca el secreto en el servicio correspondiente:

| Servicio | Como revocar |
|----------|-------------|
| **AWS** | IAM Console > Access Keys > Deactivate/Delete |
| **GitHub** | Settings > Developer Settings > Personal Access Tokens > Delete |
| **Stripe** | Dashboard > API Keys > Roll Key |
| **Azure** | Azure AD > App Registrations > Certificates & Secrets > Delete |
| **SendGrid** | Settings > API Keys > Delete |

!!! warning "Revocar PRIMERO"
    Siempre revoca **antes** de limpiar el historial. Si limpias el historial primero, un atacante que ya tiene copia del repositorio aun puede usar el secreto. La revocacion es lo unico que invalida el secreto inmediatamente.

### Paso 2: Rotar (crear nuevo secreto)

Genera nuevos secretos para reemplazar los comprometidos. Guardalos en un gestor de secretos:

- **Azure Key Vault**
- **AWS Secrets Manager**
- **HashiCorp Vault**
- Variables secretas en Azure DevOps (como configuramos en Lab 2)

### Paso 3: Limpiar el historial de git

!!! warning "Operacion destructiva"
    Reescribir el historial de git es una operacion **destructiva**. Todos los colaboradores deberan hacer `git pull --rebase` o re-clonar el repositorio. Solo hazlo cuando sea necesario y comunica al equipo antes.

Elimina el archivo con secretos del historial:

```bash title="Terminal"
# Opcion 1: git filter-branch (clasico)
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch vulnerable-app/config_temp.py" \
  --prune-empty --tag-name-filter cat -- --all

# Opcion 2: BFG Repo-Cleaner (mas rapido para repos grandes)
# Descargar: https://rtyley.github.io/bfg-repo-cleaner/
# java -jar bfg.jar --delete-files config_temp.py

# Opcion 3: git-filter-repo (recomendado)
# pip install git-filter-repo
# git filter-repo --path vulnerable-app/config_temp.py --invert-paths
```

Despues de limpiar:

```bash title="Terminal"
# Forzar push (requiere permisos)
git push origin --force --all

# Limpiar reflog local
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

## 3.5 Remediacion en nuestra rama de prueba

Para nuestro ejercicio, hagamos la remediacion simple:

```bash title="Terminal"
# Eliminar el archivo
git rm vulnerable-app/config_temp.py
git commit -m "fix: eliminar archivo con secretos de prueba"
git push origin feature/test-secret-detection
```

Ejecuta el pipeline nuevamente y verifica que el stage SecretsDetection **ya no detecta** los secretos del archivo eliminado (aunque los secretos en `.env.example` y `users.py` siguen ahi por diseño).

## 3.6 Configurar protecciones preventivas

Para evitar que secretos lleguen al repositorio en el futuro:

### Pre-commit hook

```bash title="Terminal"
# Instalar pre-commit
pip install pre-commit

# Crear configuracion
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
EOF

# Instalar el hook
pre-commit install
```

Ahora cada `git commit` ejecutara Gitleaks **antes** de permitir el commit:

```bash title="Terminal"
# Probar — esto deberia ser bloqueado
echo 'API_KEY="ghp_test123456789abcdefghijklmnopqrst"' > test_secret.py
git add test_secret.py
git commit -m "test"
# Output: Gitleaks...Failed
# El commit no se ejecuta
```

### Branch policies en Azure DevOps

1. Ve a **Repos > Branches**
2. En la rama `main`, haz clic en los tres puntos > **Branch policies**
3. Activa **Require a minimum number of reviewers**
4. En **Build Validation**, agrega tu pipeline
5. Esto obliga a que el pipeline pase antes de hacer merge a main

!!! tip "Defensa en profundidad"
    La mejor estrategia combina multiples capas:

    1. **Pre-commit hook** -- Bloquea localmente antes del commit
    2. **Pipeline CI** -- Bloquea en el servidor si se salto el hook local
    3. **Branch policies** -- Impide merge a main sin pipeline exitoso
    4. **GitHub Secret Scanning** -- Capa adicional de GitHub (si aplica)

## 3.7 Limpiar la rama de prueba

```bash title="Terminal"
git checkout main
git branch -d feature/test-secret-detection
git push origin --delete feature/test-secret-detection
```

!!! success "Paso Completado"
    Has completado el flujo completo de deteccion y remediacion de secretos: plantar, detectar con el pipeline, revocar, rotar, limpiar historial y configurar protecciones preventivas.

## Resumen del Lab 3

| Concepto | Detalle |
|----------|---------|
| **Herramienta** | Gitleaks (open source) |
| **Stage** | `SecretsDetection` (primero en el pipeline) |
| **Artefacto** | `gitleaks-report.sarif` |
| **Comportamiento** | Falla el pipeline si detecta secretos |
| **Remediacion** | Revocar, rotar, limpiar historial |
| **Prevencion** | Pre-commit hooks + branch policies |

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../step2/" class="md-button">Anterior: Paso 2</a>
  <a href="../../lab04-sast/" class="md-button md-button--primary">Siguiente: Lab 4</a>
</div>
