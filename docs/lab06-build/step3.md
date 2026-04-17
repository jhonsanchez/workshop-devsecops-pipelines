---
tags:
  - lab
  - acr
  - inmutabilidad
  - docker
---

# Paso 3 -- Inmutabilidad en ACR

!!! abstract "Objetivo"
    Verificar la imagen publicada en Azure Container Registry, inspeccionar sus capas y metadata, y configurar una politica de inmutabilidad de tags para prevenir sobrescrituras accidentales o maliciosas.

## 3.1 Verificar la imagen en ACR

### Desde Azure CLI

```bash title="Terminal"
# Listar repositorios en ACR
az acr repository list \
  --name entelgyworkshopacr \
  --output table

# Listar tags de la imagen
az acr repository show-tags \
  --name entelgyworkshopacr \
  --repository vulnerable-app \
  --orderby time_desc \
  --output table
```

Salida esperada:

```text title="Tags de la imagen"
Result
---------
142
a1b2c3d
```

### Desde el portal de Azure

1. Ve a **Azure Portal > Container Registries > entelgyworkshopacr**
2. En el menu lateral, selecciona **Repositories**
3. Haz clic en `vulnerable-app`
4. Veras la lista de tags con su fecha de push y digest

## 3.2 Inspeccionar la imagen

### Metadata de la imagen

```bash title="Terminal"
# Ver detalles del tag
az acr repository show \
  --name entelgyworkshopacr \
  --image vulnerable-app:142 \
  --output json
```

```json title="Metadata de la imagen"
{
  "changeableAttributes": {
    "deleteEnabled": true,
    "listEnabled": true,
    "readEnabled": true,
    "writeEnabled": true
  },
  "createdTime": "2026-04-08T...",
  "digest": "sha256:abc123...",
  "lastUpdateTime": "2026-04-08T...",
  "name": "142",
  "signed": false
}
```

### Inspeccionar capas

```bash title="Terminal"
# Inspeccionar manifest (muestra capas de la imagen)
az acr manifest list-metadata \
  --name vulnerable-app \
  --registry entelgyworkshopacr \
  --output table
```

Si tienes la imagen localmente:

```bash title="Terminal"
# Ver historial de capas
docker history vulnerable-app:local-test --no-trunc

# Inspeccionar labels
docker inspect vulnerable-app:local-test --format '{{ json .Config.Labels }}' | python3 -m json.tool
```

Las labels OCI que agregamos en el paso anterior deberian aparecer:

```json title="Labels OCI"
{
  "org.opencontainers.image.source": "https://github.com/jhonsanchez/workshop-devsecops-pipelines",
  "org.opencontainers.image.revision": "a1b2c3d4e5f6...",
  "org.opencontainers.image.created": "2026-04-08T10:30:00Z",
  "org.opencontainers.image.title": "vulnerable-app"
}
```

## 3.3 Configurar inmutabilidad de tags

La inmutabilidad de tags impide que un tag existente sea sobrescrito con una nueva imagen. Esto previene:

- **Ataques de supply chain** -- Un atacante no puede reemplazar una imagen ya publicada
- **Errores accidentales** -- Un push repetido no sobrescribe la version anterior
- **Auditabilidad** -- Cada tag apunta siempre a la misma imagen

### Habilitar inmutabilidad a nivel de repositorio

```bash title="Terminal — Azure CLI"
# Habilitar inmutabilidad en el repositorio
az acr repository update \
  --name entelgyworkshopacr \
  --image vulnerable-app \
  --write-enabled false
```

!!! warning "Efecto de la inmutabilidad"
    Una vez habilitada la inmutabilidad de escritura en un repositorio, **no podras**:

    - Hacer push de un tag que ya existe
    - Eliminar tags existentes
    - Modificar el manifest de una imagen

    Tags **nuevos** si se pueden agregar. Este es exactamente el comportamiento que queremos con tags basados en Build ID.

### Politica a nivel de registro (Premium SKU)

Si tienes ACR con SKU Premium, puedes configurar una politica global de retencion:

```bash title="Terminal — Azure CLI (Premium SKU)"
# Habilitar politica de retencion de 30 dias para manifests sin tags
az acr config retention update \
  --registry entelgyworkshopacr \
  --status enabled \
  --days 30 \
  --type UntaggedManifests
```

!!! info "SKU de ACR"
    | SKU | Inmutabilidad de tags | Retencion | Content Trust |
    |-----|----------------------|-----------|---------------|
    | Basic | Manual por repositorio | No | No |
    | Standard | Manual por repositorio | No | No |
    | Premium | Politica global + por repositorio | Si | Si |

## 3.4 Verificar la inmutabilidad

Intenta hacer push del mismo tag:

```bash title="Terminal"
# Esto deberia FALLAR si la inmutabilidad esta habilitada
docker tag vulnerable-app:local-test entelgyworkshopacr.azurecr.io/vulnerable-app:142
docker push entelgyworkshopacr.azurecr.io/vulnerable-app:142
```

Salida esperada:

```text title="Error de inmutabilidad"
denied: The operation is disallowed. Repository is marked as read-only.
```

!!! tip "Para el workshop"
    Si no puedes habilitar inmutabilidad en tu ACR de prueba, es suficiente con entender el concepto. En el pipeline ya estamos usando tags basados en Build ID (que son unicos), lo que logra inmutabilidad de facto.

## 3.5 Estrategia de tagging recomendada

| Estrategia | Ejemplo | Inmutable | Recomendado |
|------------|---------|-----------|-------------|
| `:latest` | `app:latest` | No | Nunca en produccion |
| Build ID | `app:142` | Si | Si |
| Git SHA | `app:a1b2c3d` | Si | Si |
| Semver | `app:1.2.3` | Si (si se respeta) | Para releases |
| Fecha | `app:2026-04-08` | No (multiples builds/dia) | No |
| Build ID + SHA | `app:142` + `app:a1b2c3d` | Si | Mejor opcion |

Nuestra estrategia actual (Build ID + SHA corto) es la recomendada porque:

- **Build ID** es secuencial y facil de identificar la version
- **SHA** permite trazar exactamente que commit produjo la imagen
- Ambos son **unicos e inmutables** por naturaleza

## 3.6 Limpieza de imagenes antiguas

Para evitar que el registro crezca indefinidamente, configura una politica de limpieza:

```bash title="Terminal — Azure CLI"
# Purgar imagenes de mas de 30 dias (mantener las ultimas 10)
az acr run \
  --cmd "acr purge --filter 'vulnerable-app:.*' \
    --ago 30d --keep 10 --untagged" \
  --registry entelgyworkshopacr \
  /dev/null
```

!!! tip "Automatizar limpieza"
    Puedes crear un **ACR Task** programado para ejecutar la purga automaticamente:

    ```bash
    az acr task create \
      --name purge-old-images \
      --registry entelgyworkshopacr \
      --cmd "acr purge --filter 'vulnerable-app:.*' --ago 30d --keep 10" \
      --schedule "0 0 * * *" \
      --context /dev/null
    ```

!!! success "Paso Completado"
    Has verificado la imagen en ACR, inspeccionado sus capas y labels, y configurado (o entendido) la inmutabilidad de tags para proteger las imagenes publicadas.

## Resumen del Lab 6

| Concepto | Detalle |
|----------|---------|
| **Herramientas** | Hadolint, Docker, ACR |
| **Stage** | `Build` (cuarto en el pipeline) |
| **Dockerfile** | `Dockerfile.secure` (hardened) |
| **Tags** | `$(Build.BuildId)` + SHA corto (nunca `:latest`) |
| **Labels** | OCI standard (source, revision, created) |
| **Tarea** | `Docker@2` (build + push) |
| **Seguridad** | Non-root, slim base, no secrets, inmutabilidad |

## Estado actual del pipeline

```text title="Stages implementados"
SecretsDetection (Gitleaks)     → Implementado - Lab 3
SAST (Semgrep)                  → Implementado - Lab 4
SCA (Trivy fs)                  → Implementado - Lab 5
Build (Docker + ACR)            → Implementado - Lab 6
ImageScan                       → Placeholder  - Lab 7
IaCScan                         → Placeholder  - Lab 9
DeployStaging                   → Placeholder  - Lab 10
DAST                            → Placeholder  - Lab 8
DeployProduction                → Placeholder  - Lab 10
Monitor                         → Placeholder  - Lab 11
```

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../step2/" class="md-button">Anterior: Paso 2</a>
  <a href="../../lab07-image-signing/" class="md-button md-button--primary">Siguiente: Lab 7</a>
</div>
