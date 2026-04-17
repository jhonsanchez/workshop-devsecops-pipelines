---
tags:
  - lab
  - docker
  - acr
  - pipeline
  - build
---

# Paso 2 -- Stage de Build + ACR

!!! abstract "Objetivo"
    Implementar el stage `Build` en `azure-pipelines.yml` usando la tarea `Docker@2` de Azure DevOps. Construir la imagen Docker con el Dockerfile seguro, tagearla con `$(Build.BuildId)` y el SHA del commit (nunca `:latest`), y publicarla en Azure Container Registry.

## 2.1 Reemplazar el placeholder de Build

Abre `azure-pipelines.yml` y reemplaza el stage `Build` completo:

```yaml title="azure-pipelines.yml — stage Build"
  # ──────────────────────────────────────────────
  # Stage 4: Build - Imagen Docker + ACR (Lab 6)
  # ──────────────────────────────────────────────
  - stage: Build
    displayName: 'Build - Imagen Docker'
    dependsOn: SCA
    jobs:
      - job: DockerBuild
        displayName: 'Build y Push a ACR'
        steps:
          - checkout: self
            displayName: 'Checkout del repositorio'

          # --- Paso 1: Hadolint — Lint del Dockerfile ---
          - script: |
              echo "=== Hadolint — Lint del Dockerfile ==="
              echo ""

              docker run --rm \
                -v "$(Build.SourcesDirectory)/$(appDirectory)/Dockerfile.secure:/Dockerfile" \
                hadolint/hadolint:latest \
                hadolint /Dockerfile \
                  --format json \
                  --failure-threshold error

              HADOLINT_EXIT=$?

              if [ $HADOLINT_EXIT -eq 0 ]; then
                echo "Hadolint: Dockerfile.secure pasa todas las validaciones"
              else
                echo "##[error]Hadolint encontro errores en Dockerfile.secure"
              fi

              exit $HADOLINT_EXIT
            displayName: 'Hadolint - Lint del Dockerfile'

          # --- Paso 2: Preparar tags ---
          - script: |
              # Obtener short SHA del commit
              SHORT_SHA=$(echo $(Build.SourceVersion) | cut -c1-7)

              echo "=== Tags de la imagen ==="
              echo "Build ID:  $(Build.BuildId)"
              echo "Short SHA: $SHORT_SHA"
              echo "Registry:  $(acrLoginServer)"
              echo "Image:     $(imageName)"
              echo ""
              echo "Tags que se aplicaran:"
              echo "  $(acrLoginServer)/$(imageName):$(Build.BuildId)"
              echo "  $(acrLoginServer)/$(imageName):$SHORT_SHA"

              # Exportar para usar en pasos siguientes
              echo "##vso[task.setvariable variable=shortSha]$SHORT_SHA"
            displayName: 'Preparar tags de imagen'

          # --- Paso 3: Build de la imagen Docker ---
          - task: Docker@2
            displayName: 'Build de imagen Docker'
            inputs:
              containerRegistry: 'acr-service-connection'
              repository: '$(imageName)'
              command: 'build'
              Dockerfile: '$(Build.SourcesDirectory)/$(appDirectory)/Dockerfile.secure'
              buildContext: '$(Build.SourcesDirectory)/$(appDirectory)'
              tags: |
                $(Build.BuildId)
                $(shortSha)
              arguments: |
                --label org.opencontainers.image.source=$(Build.Repository.Uri)
                --label org.opencontainers.image.revision=$(Build.SourceVersion)
                --label org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                --label org.opencontainers.image.title=$(imageName)

          # --- Paso 4: Push a ACR ---
          - task: Docker@2
            displayName: 'Push a Azure Container Registry'
            inputs:
              containerRegistry: 'acr-service-connection'
              repository: '$(imageName)'
              command: 'push'
              tags: |
                $(Build.BuildId)
                $(shortSha)

          # --- Paso 5: Guardar referencia de la imagen ---
          - script: |
              IMAGE_REF="$(acrLoginServer)/$(imageName):$(Build.BuildId)"
              echo "=== Imagen publicada ==="
              echo "Referencia completa: $IMAGE_REF"
              echo "Tags:"
              echo "  - $(Build.BuildId)"
              echo "  - $(shortSha)"
              echo ""
              echo "##vso[task.setvariable variable=imageRef;isOutput=true]$IMAGE_REF"
            name: imageOutput
            displayName: 'Registrar referencia de imagen'
```

## 2.2 Analizar la configuracion

### Hadolint como primer paso

Antes de construir la imagen, ejecutamos Hadolint para validar que el Dockerfile cumple las mejores practicas:

```bash
hadolint /Dockerfile \
  --format json \
  --failure-threshold error
```

| Parametro | Efecto |
|-----------|--------|
| `--format json` | Salida JSON para procesamiento |
| `--failure-threshold error` | Solo falla en errores, permite warnings |

### Tarea Docker@2

Azure DevOps provee la tarea `Docker@2` que simplifica las operaciones con Docker:

```yaml
- task: Docker@2
  inputs:
    containerRegistry: 'acr-service-connection'
    repository: '$(imageName)'
    command: 'build'
    Dockerfile: '...'
    buildContext: '...'
    tags: |
      $(Build.BuildId)
      $(shortSha)
```

!!! info "Service Connection para ACR"
    La tarea `Docker@2` necesita una **service connection** de tipo "Docker Registry" configurada para tu ACR:

    1. Ve a **Project Settings > Service connections**
    2. **New service connection > Docker Registry**
    3. Selecciona **Azure Container Registry**
    4. Nombra la connection: `acr-service-connection`
    5. Selecciona tu suscripcion y ACR

### Tags inmutables (nunca :latest)

```yaml
tags: |
  $(Build.BuildId)
  $(shortSha)
```

Usamos **dos tags** por imagen:

- **`$(Build.BuildId)`** -- Numero secuencial del build (ej: `142`)
- **`$(shortSha)`** -- SHA corto del commit (ej: `a1b2c3d`)

!!! warning "Nunca usar :latest"
    El tag `:latest` es mutable: cualquier push lo sobrescribe. Esto significa:

    - No puedes saber que version esta desplegada
    - No puedes hacer rollback a una version especifica
    - Los pods pueden reiniciarse con una version diferente

    Siempre usa tags inmutables basados en el build ID o commit SHA.

### Labels OCI

```yaml
arguments: |
  --label org.opencontainers.image.source=...
  --label org.opencontainers.image.revision=...
  --label org.opencontainers.image.created=...
```

Las labels OCI (Open Container Initiative) son metadata estandar que permite trazar la imagen hasta su codigo fuente:

| Label | Contenido |
|-------|-----------|
| `image.source` | URL del repositorio |
| `image.revision` | SHA completo del commit |
| `image.created` | Timestamp de creacion |
| `image.title` | Nombre de la imagen |

### Variable de salida

```yaml
echo "##vso[task.setvariable variable=imageRef;isOutput=true]$IMAGE_REF"
```

Esto exporta la referencia completa de la imagen (`acrname.azurecr.io/vulnerable-app:142`) para que stages posteriores (ImageScan, Deploy) puedan usarla sin hardcodearla.

## 2.3 Configuracion alternativa sin ACR

Si no tienes un ACR, puedes usar Docker Hub o simplemente construir la imagen sin push:

```yaml title="Alternativa: solo build (sin push)"
          # Build sin push (para workshop sin ACR)
          - script: |
              cd $(Build.SourcesDirectory)/$(appDirectory)

              SHORT_SHA=$(echo $(Build.SourceVersion) | cut -c1-7)

              docker build \
                -f Dockerfile.secure \
                -t $(imageName):$(Build.BuildId) \
                -t $(imageName):$SHORT_SHA \
                --label org.opencontainers.image.revision=$(Build.SourceVersion) \
                .

              echo "=== Imagen construida ==="
              docker images $(imageName)

              echo ""
              echo "=== Verificar non-root ==="
              docker run --rm $(imageName):$(Build.BuildId) whoami
            displayName: 'Build de imagen Docker (local)'
```

## 2.4 Hacer push y verificar

```bash title="Terminal"
git add azure-pipelines.yml
git commit -m "lab06: implementar stage Build con Docker y ACR"
git push origin main
```

Verifica en Azure DevOps:

1. **SecretsDetection** > **SAST** > **SCA** > **Build** se ejecutan en secuencia
2. Hadolint valida el Dockerfile.secure sin errores
3. La imagen Docker se construye correctamente
4. Los tags `$(Build.BuildId)` y SHA corto se aplican
5. (Si tienes ACR) La imagen se publica en el registro

!!! tip "Logs de Docker"
    En los logs del step de build, puedes ver cada capa del Dockerfile ejecutandose. Verifica que:

    - La imagen base es `python:3.11-slim-bookworm`
    - Se crea el usuario `app`
    - El `HEALTHCHECK` esta configurado

!!! success "Paso Completado"
    El stage Build esta implementado con Hadolint + Docker@2. La imagen se construye con el Dockerfile seguro, se tagea con Build ID y SHA (nunca :latest), y se publica en ACR con labels OCI.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../step1/" class="md-button">Anterior: Paso 1</a>
  <a href="../step3/" class="md-button md-button--primary">Paso 3: Inmutabilidad en ACR</a>
</div>
