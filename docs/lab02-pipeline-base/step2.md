---
tags:
  - lab
  - azure-devops
  - variables
  - key-vault
---

# Paso 2 -- Variables y Secretos

!!! abstract "Objetivo"
    Configurar variables no sensibles en el pipeline YAML, crear un grupo de variables en Azure DevOps y vincularlo con Azure Key Vault para gestionar secretos de forma segura.

## 2.1 Agregar variables al pipeline

Descomenta y completa la seccion `variables` en `azure-pipelines.yml`. Agrega las siguientes variables justo despues del bloque `pool`:

```yaml title="azure-pipelines.yml (seccion variables)"
# --- Variables del Pipeline ---
variables:
  # Variables no sensibles — directamente en YAML
  - name: imageName
    value: 'vulnerable-app'
  - name: imageTag
    value: '$(Build.BuildId)'
  - name: acrName
    value: 'entelgyworkshopacr'
  - name: acrLoginServer
    value: '$(acrName).azurecr.io'
  - name: dockerfilePath
    value: 'vulnerable-app/Dockerfile.secure'
  - name: appDirectory
    value: 'vulnerable-app'

  # Grupo de variables (incluye secretos de Key Vault)
  - group: devsecops-workshop-secrets
```

!!! warning "Nunca secretos en YAML"
    Las variables definidas directamente en el YAML son visibles en el repositorio. **Nunca** pongas credenciales, tokens, o contraseñas aqui. Para secretos, usamos grupos de variables vinculados a Azure Key Vault.

## 2.2 Crear el grupo de variables en Azure DevOps

1. En Azure DevOps, ve a **Pipelines > Library**
2. Haz clic en **+ Variable group**
3. Configura:

    | Campo | Valor |
    |-------|-------|
    | **Variable group name** | `devsecops-workshop-secrets` |
    | **Description** | Secretos para el pipeline DevSecOps |

4. Agrega las siguientes variables (haz clic en **+ Add** para cada una):

    | Variable | Valor | Tipo |
    |----------|-------|------|
    | `ACR_USERNAME` | `entelgyworkshopacr` | Plain text |
    | `ACR_PASSWORD` | *(tu contraseña de ACR)* | **Secret** (candado) |
    | `SEMGREP_APP_TOKEN` | *(tu token de Semgrep, si aplica)* | **Secret** |
    | `COSIGN_PASSWORD` | *(contraseña para firma de imagenes)* | **Secret** |

5. Haz clic en el icono de **candado** junto a cada variable secreta para marcarla como tal
6. Haz clic en **Save**

!!! tip "Variables secretas"
    Las variables marcadas como secretas:

    - No se muestran en los logs (se reemplazan por `***`)
    - No se pueden ver una vez guardadas
    - Solo estan disponibles en el pipeline en tiempo de ejecucion
    - No se exportan automaticamente a variables de entorno por seguridad

## 2.3 Vincular con Azure Key Vault (opcional)

Si tienes acceso a una suscripcion de Azure con un Key Vault, puedes vincular el grupo de variables directamente:

1. En la pantalla del variable group, activa el toggle **Link secrets from an Azure key vault as variables**
2. Selecciona la **Azure subscription** (service connection de tipo Azure Resource Manager)
3. Selecciona el **Key vault name**
4. Haz clic en **+ Add** y selecciona los secretos del vault que quieras usar

!!! info "Simulacion sin Key Vault"
    Si no tienes un Key Vault disponible, puedes usar el grupo de variables normal con secretos marcados con el candado. El flujo del pipeline sera identico; la unica diferencia es que con Key Vault los secretos se sincronizan automaticamente.

### Crear el Key Vault (si aplica)

Si necesitas crear un Key Vault para el workshop:

```bash title="Terminal — Azure CLI"
# Crear grupo de recursos
az group create \
  --name rg-workshop-secrets \
  --location westeurope

# Crear Key Vault
az keyvault create \
  --name kv-devsecops-workshop \
  --resource-group rg-workshop-secrets \
  --location westeurope \
  --sku standard

# Agregar secretos
az keyvault secret set \
  --vault-name kv-devsecops-workshop \
  --name "ACR-PASSWORD" \
  --value "tu-password-segura"

az keyvault secret set \
  --vault-name kv-devsecops-workshop \
  --name "COSIGN-PASSWORD" \
  --value "cosign-key-password"
```

!!! warning "Nombres de secretos en Key Vault"
    Azure Key Vault no permite guiones bajos (`_`) en nombres de secretos. Usa guiones (`-`). Azure DevOps convierte automaticamente `ACR-PASSWORD` a la variable `ACR_PASSWORD` en el pipeline.

## 2.4 Autorizar el grupo de variables

Despues de crear el grupo de variables, necesitas autorizar su uso en el pipeline:

1. La primera vez que el pipeline se ejecute con `- group: devsecops-workshop-secrets`, Azure DevOps mostrara un error de autorizacion
2. Haz clic en el boton **Permit** que aparece en la ejecucion del pipeline
3. Confirma la autorizacion

Alternativamente, puedes pre-autorizar:

1. Ve a **Pipelines > Library** > tu variable group
2. En la pestaña **Pipeline permissions**
3. Haz clic en **+** y selecciona tu pipeline
4. Guarda

## 2.5 Verificar que las variables funcionan

Modifica el primer stage para verificar que las variables estan disponibles:

```yaml title="azure-pipelines.yml (stage SecretsDetection actualizado)"
  - stage: SecretsDetection
    displayName: 'Deteccion de Secretos'
    jobs:
      - job: Placeholder
        displayName: 'Pendiente - Lab 3'
        steps:
          - script: |
              echo "=== Stage: SecretsDetection ==="
              echo "Este stage se implementara en Lab 3 con Gitleaks"
              echo ""
              echo "--- Variables disponibles ---"
              echo "Image Name:   $(imageName)"
              echo "ACR Name:     $(acrName)"
              echo "ACR Server:   $(acrLoginServer)"
              echo "App Dir:      $(appDirectory)"
              echo "Build ID:     $(Build.BuildId)"
            displayName: 'Placeholder - Gitleaks'
```

!!! warning "Variables secretas en logs"
    Observa que **no** hacemos `echo` de `$(ACR_PASSWORD)`. Si lo intentaras, veras `***` en los logs. Azure DevOps enmascara automaticamente las variables marcadas como secretas.

## 2.6 Hacer push y verificar

```bash title="Terminal"
git add azure-pipelines.yml
git commit -m "lab02: agregar variables y grupo de secretos al pipeline"
git push origin main
```

Verifica en la ejecucion del pipeline:

1. Las variables no sensibles se muestran correctamente en los logs
2. Si configuraste el grupo de variables, la ejecucion deberia pedir autorizacion la primera vez
3. Todos los stages siguen pasando exitosamente

!!! success "Paso Completado"
    Tu pipeline tiene ahora la estructura completa de 10 stages con dependencias, variables de configuracion y un grupo de secretos. Esta listo para que cada lab posterior rellene un stage con herramientas de seguridad reales.

## Resumen del pipeline actual

```yaml title="Estructura actual del azure-pipelines.yml"
trigger: main
pool: ubuntu-latest
variables:
  - imageName, imageTag, acrName, acrLoginServer, ...
  - group: devsecops-workshop-secrets

stages:
  SecretsDetection → SAST → SCA → Build
                                    ├→ ImageScan ──┐
                                    └→ IaCScan ────┤
                                                   ↓
                              DeployStaging → DAST → DeployProduction → Monitor
```

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../step1/" class="md-button">Anterior: Paso 1</a>
  <a href="../../lab03-secretos/" class="md-button md-button--primary">Siguiente: Lab 3</a>
</div>
