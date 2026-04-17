---
tags:
  - lab
  - github-actions
  - variables
  - secrets
---

# Paso 2 -- Variables y Secretos

!!! abstract "Objetivo"
    Configurar variables no sensibles en el workflow YAML y configurar GitHub Secrets para gestionar credenciales de forma segura.

## 2.1 Agregar variables al workflow

Descomenta y completa la seccion `env` en `.github/workflows/devsecops.yml`. Agrega las siguientes variables a nivel de workflow:

```yaml title=".github/workflows/devsecops.yml (seccion env)"
# --- Variables del Workflow ---
env:
  # Variables no sensibles — directamente en YAML
  IMAGE_NAME: 'vulnerable-app'
  IMAGE_TAG: ${{ github.run_number }}
  REGISTRY: 'ghcr.io'
  REGISTRY_URL: 'ghcr.io/${{ github.repository_owner }}'
  DOCKERFILE_PATH: 'vulnerable-app/Dockerfile.secure'
  APP_DIRECTORY: 'vulnerable-app'
```

!!! warning "Nunca secretos en YAML"
    Las variables definidas directamente en el YAML son visibles en el repositorio. **Nunca** pongas credenciales, tokens, o contraseñas aqui. Para secretos, usamos GitHub Secrets.

## 2.2 Crear los secretos en GitHub

1. En GitHub, ve a tu repositorio > **Settings** > **Secrets and variables** > **Actions**
2. Haz clic en **New repository secret**
3. Agrega los siguientes secretos (haz clic en **Add secret** para cada uno):

    | Secreto | Valor | Descripcion |
    |---------|-------|-------------|
    | `REGISTRY_USERNAME` | *(tu usuario de GitHub)* | Username para GHCR |
    | `REGISTRY_PASSWORD` | *(tu Personal Access Token)* | Token con permisos `write:packages` |
    | `SEMGREP_APP_TOKEN` | *(tu token de Semgrep, si aplica)* | Token de Semgrep |
    | `COSIGN_PASSWORD` | *(contraseña para firma de imagenes)* | Password de clave Cosign |

!!! tip "GitHub Secrets"
    Los secretos en GitHub:

    - No se muestran en los logs (se reemplazan por `***`)
    - No se pueden ver una vez guardados
    - Solo estan disponibles en el workflow en tiempo de ejecucion
    - Se acceden con la sintaxis `${{ secrets.NOMBRE_SECRETO }}`

!!! info "GITHUB_TOKEN"
    GitHub proporciona automaticamente el token `GITHUB_TOKEN` en cada ejecucion del workflow. Este token tiene permisos para push a GHCR sin necesidad de crear un PAT adicional. En la mayoria de casos, puedes usar `${{ secrets.GITHUB_TOKEN }}` directamente.

## 2.3 Variables de entorno por ambiente (opcional)

Si quieres tener variables diferentes por ambiente (staging vs production), puedes usar **GitHub Environments**:

1. Ve a **Settings** > **Environments**
2. Crea un ambiente (ej: `staging`, `production`)
3. Agrega secretos o variables especificas del ambiente

!!! info "Simulacion sin Environments"
    Si no necesitas diferenciar ambientes por ahora, puedes usar secretos a nivel de repositorio. El flujo del workflow sera identico; la unica diferencia es que con Environments puedes tener diferentes valores por ambiente.

## 2.4 Permisos del GITHUB_TOKEN

Para que el workflow pueda hacer push de imagenes a GHCR, necesitas configurar los permisos del token:

1. Ve a **Settings** > **Actions** > **General**
2. En la seccion **Workflow permissions**, selecciona **Read and write permissions**
3. Haz clic en **Save**

Tambien puedes definir permisos granulares en el YAML:

```yaml title="Permisos en el workflow"
permissions:
  contents: read
  packages: write
```

## 2.5 Verificar que las variables funcionan

Modifica el primer job para verificar que las variables estan disponibles:

```yaml title=".github/workflows/devsecops.yml (job secrets-detection actualizado)"
  secrets-detection:
    name: 'Deteccion de Secretos'
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo "=== Job: SecretsDetection ==="
          echo "Este job se implementara en Lab 3 con Gitleaks"
          echo ""
          echo "--- Variables disponibles ---"
          echo "Image Name:   ${{ env.IMAGE_NAME }}"
          echo "Registry:     ${{ env.REGISTRY }}"
          echo "Registry URL: ${{ env.REGISTRY_URL }}"
          echo "App Dir:      ${{ env.APP_DIRECTORY }}"
          echo "Run Number:   ${{ github.run_number }}"
        name: 'Placeholder - Gitleaks'
```

!!! warning "Variables secretas en logs"
    Observa que **no** hacemos `echo` de `${{ secrets.REGISTRY_PASSWORD }}`. Si lo intentaras, veras `***` en los logs. GitHub Actions enmascara automaticamente los secretos.

## 2.6 Hacer push y verificar

```bash title="Terminal"
git add .github/workflows/devsecops.yml
git commit -m "lab02: agregar variables y secretos al workflow"
git push origin main
```

Verifica en la ejecucion del workflow:

1. Las variables no sensibles se muestran correctamente en los logs
2. Los secretos se acceden con `${{ secrets.NOMBRE }}` en los jobs que los necesiten
3. Todos los jobs siguen pasando exitosamente

!!! success "Paso Completado"
    Tu workflow tiene ahora la estructura completa de 10 jobs con dependencias, variables de configuracion y secretos en GitHub Secrets. Esta listo para que cada lab posterior rellene un job con herramientas de seguridad reales.

## Resumen del workflow actual

```yaml title="Estructura actual del .github/workflows/devsecops.yml"
on: push (main)
env: IMAGE_NAME, IMAGE_TAG, REGISTRY, REGISTRY_URL, ...
# secrets configurados en GitHub Settings

jobs:
  secrets-detection → sast → sca → build
                                      ├→ image-scan ──┐
                                      └→ iac-scan ────┤
                                                      ↓
                                deploy-staging → dast → deploy-production → monitor
```

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../step1/" class="md-button">Anterior: Paso 1</a>
  <a href="../../lab03-secretos/" class="md-button md-button--primary">Siguiente: Lab 3</a>
</div>
