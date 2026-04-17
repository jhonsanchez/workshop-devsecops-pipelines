---
tags:
  - lab
  - docker
  - acr
  - pipeline
  - build
---

# Paso 2 -- Stage de Build + GHCR

!!! abstract "Objetivo"
    Implementar el stage `Build` en `.github/workflows/devsecops.yml` usando la tarea `docker/build-push-action@v5` de GitHub Actions. Construir la imagen Docker con el Dockerfile seguro, tagearla con `${{ github.run_number }}` y el SHA del commit (nunca `:latest`), y publicarla en GitHub Container Registry.

## 2.1 Reemplazar el placeholder de Build

Abre `.github/workflows/devsecops.yml` y reemplaza el stage `Build` completo:

```yaml title=".github/workflows/devsecops.yml — stage Build"
  # ──────────────────────────────────────────────
  # Stage 4: Build - Imagen Docker + GHCR (Lab 6)
  # ──────────────────────────────────────────────
  - stage: Build
    name: 'Build - Imagen Docker'
    dependsOn: SCA
    jobs:
      - job: DockerBuild
        name: 'Build y Push a GHCR'
        steps:
          - checkout: self
            name: 'Checkout del repositorio'

          # --- Paso 1: Hadolint — Lint del Dockerfile ---
          - script: |
              echo "=== Hadolint — Lint del Dockerfile ==="
              echo ""

              docker run --rm \
                -v "${{ github.workspace }}/${{ env.APP_DIRECTORY }}/Dockerfile.secure:/Dockerfile" \
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
            name: 'Hadolint - Lint del Dockerfile'

          # --- Paso 2: Preparar tags ---
          - script: |
              # Obtener short SHA del commit
              SHORT_SHA=$(echo ${{ github.sha }} | cut -c1-7)

              echo "=== Tags de la imagen ==="
              echo "Build ID:  ${{ github.run_number }}"
              echo "Short SHA: $SHORT_SHA"
              echo "Registry:  ${{ env.REGISTRY_URL }}"
              echo "Image:     ${{ env.IMAGE_NAME }}"
              echo ""
              echo "Tags que se aplicaran:"
              echo "  ${{ env.REGISTRY_URL }}/${{ env.IMAGE_NAME }}:${{ github.run_number }}"
              echo "  ${{ env.REGISTRY_URL }}/${{ env.IMAGE_NAME }}:$SHORT_SHA"

              # Exportar para usar en pasos siguientes
              echo "echo "shortSha]$SHORT_SHA"
            name: 'Preparar tags de imagen'

          # --- Paso 3: Build de la imagen Docker ---
          - uses: docker/build-push-action@v5
            name: 'Build de imagen Docker'
            inputs:
              containerRegistry: 'acr-service-connection'
              repository: '${{ env.IMAGE_NAME }}'
              command: 'build'
              Dockerfile: '${{ github.workspace }}/${{ env.APP_DIRECTORY }}/Dockerfile.secure'
              buildContext: '${{ github.workspace }}/${{ env.APP_DIRECTORY }}'
              tags: |
                ${{ github.run_number }}
                $(shortSha)
              arguments: |
                --label org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }}
                --label org.opencontainers.image.revision=${{ github.sha }}
                --label org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                --label org.opencontainers.image.title=${{ env.IMAGE_NAME }}

          # --- Paso 4: Push a GHCR ---
          - uses: docker/build-push-action@v5
            name: 'Push a GitHub Container Registry'
            inputs:
              containerRegistry: 'acr-service-connection'
              repository: '${{ env.IMAGE_NAME }}'
              command: 'push'
              tags: |
                ${{ github.run_number }}
                $(shortSha)

          # --- Paso 5: Guardar referencia de la imagen ---
          - script: |
              IMAGE_REF="${{ env.REGISTRY_URL }}/${{ env.IMAGE_NAME }}:${{ github.run_number }}"
              echo "=== Imagen publicada ==="
              echo "Referencia completa: $IMAGE_REF"
              echo "Tags:"
              echo "  - ${{ github.run_number }}"
              echo "  - $(shortSha)"
              echo ""
              echo "echo "imageRef;isOutput=true]$IMAGE_REF"
            name: imageOutput
            name: 'Registrar referencia de imagen'
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

### Tarea docker/build-push-action@v5

GitHub Actions provee la tarea `docker/build-push-action@v5` que simplifica las operaciones con Docker:

```yaml
- uses: docker/build-push-action@v5
  inputs:
    containerRegistry: 'acr-service-connection'
    repository: '${{ env.IMAGE_NAME }}'
    command: 'build'
    Dockerfile: '...'
    buildContext: '...'
    tags: |
      ${{ github.run_number }}
      $(shortSha)
```

!!! info "Service Connection para GHCR"
    La tarea `docker/build-push-action@v5` necesita una **GITHUB_TOKEN** de tipo "Docker Registry" configurada para tu GHCR:

    1. Ve a **Project Settings > Service connections**
    2. **New GITHUB_TOKEN > Docker Registry**
    3. Selecciona **GitHub Container Registry**
    4. Nombra la connection: `acr-service-connection`
    5. Selecciona tu suscripcion y GHCR

### Tags inmutables (nunca :latest)

```yaml
tags: |
  ${{ github.run_number }}
  $(shortSha)
```

Usamos **dos tags** por imagen:

- **`${{ github.run_number }}`** -- Numero secuencial del build (ej: `142`)
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
echo "echo "imageRef;isOutput=true]$IMAGE_REF"
```

Esto exporta la referencia completa de la imagen (`ghcr.io/owner/vulnerable-app:142`) para que stages posteriores (ImageScan, Deploy) puedan usarla sin hardcodearla.

## 2.3 Configuracion alternativa sin GHCR

Si no tienes un GHCR, puedes usar Docker Hub o simplemente construir la imagen sin push:

```yaml title="Alternativa: solo build (sin push)"
          # Build sin push (para workshop sin GHCR)
          - script: |
              cd ${{ github.workspace }}/${{ env.APP_DIRECTORY }}

              SHORT_SHA=$(echo ${{ github.sha }} | cut -c1-7)

              docker build \
                -f Dockerfile.secure \
                -t ${{ env.IMAGE_NAME }}:${{ github.run_number }} \
                -t ${{ env.IMAGE_NAME }}:$SHORT_SHA \
                --label org.opencontainers.image.revision=${{ github.sha }} \
                .

              echo "=== Imagen construida ==="
              docker images ${{ env.IMAGE_NAME }}

              echo ""
              echo "=== Verificar non-root ==="
              docker run --rm ${{ env.IMAGE_NAME }}:${{ github.run_number }} whoami
            name: 'Build de imagen Docker (local)'
```

## 2.4 Hacer push y verificar

```bash title="Terminal"
git add .github/workflows/devsecops.yml
git commit -m "lab06: implementar stage Build con Docker y GHCR"
git push origin main
```

Verifica en GitHub Actions:

1. **SecretsDetection** > **SAST** > **SCA** > **Build** se ejecutan en secuencia
2. Hadolint valida el Dockerfile.secure sin errores
3. La imagen Docker se construye correctamente
4. Los tags `${{ github.run_number }}` y SHA corto se aplican
5. (Si tienes GHCR) La imagen se publica en el registro

!!! tip "Logs de Docker"
    En los logs del step de build, puedes ver cada capa del Dockerfile ejecutandose. Verifica que:

    - La imagen base es `python:3.11-slim-bookworm`
    - Se crea el usuario `app`
    - El `HEALTHCHECK` esta configurado

!!! success "Paso Completado"
    El stage Build esta implementado con Hadolint + docker/build-push-action@v5. La imagen se construye con el Dockerfile seguro, se tagea con Build ID y SHA (nunca :latest), y se publica en GHCR con labels OCI.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../step1/" class="md-button">Anterior: Paso 1</a>
  <a href="../step3/" class="md-button md-button--primary">Paso 3: Inmutabilidad en GHCR</a>
</div>
