---
tags:
  - lab
  - cosign
  - container-security
  - signing
---

# Paso 2 -- Firma de Imagen con Cosign

!!! abstract "Objetivo"
    Instalar Cosign en el pipeline, generar un par de claves, firmar la imagen de contenedor en GHCR despues de que pase el escaneo de Trivy, y subir la firma al registro.

## Contexto

La firma de imagenes establece una **cadena de confianza**: solo las imagenes que han pasado los controles de seguridad y han sido firmadas por el pipeline autorizado pueden desplegarse. Cosign (parte del proyecto Sigstore) es la herramienta estandar para firmar imagenes OCI.

```mermaid
sequenceDiagram
    participant Pipeline
    participant GHCR
    participant Cosign
    Pipeline->>GHCR: docker push (Lab 6)
    Pipeline->>Pipeline: Trivy scan (Paso 1)
    Pipeline->>Cosign: cosign sign --key cosign.key
    Cosign->>GHCR: Push firma (.sig)
    Note over GHCR: Imagen + Firma almacenadas juntas
```

## 2.1 Generar par de claves Cosign

Primero, genera un par de claves que el pipeline usara para firmar. Esto se hace **una sola vez** y las claves se almacenan como secretos.

```bash title="Generar claves Cosign (ejecutar localmente)"
# Instalar cosign
# macOS:
brew install cosign

# Linux:
# curl -fsSL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign
# chmod +x /usr/local/bin/cosign

# Generar par de claves
cosign generate-key-pair

# Esto genera:
#   cosign.key  (clave privada - SECRETA)
#   cosign.pub  (clave publica - se puede compartir)
```

!!! warning "Proteger la clave privada"
    La clave privada (`cosign.key`) y su password **nunca** deben estar en el repositorio. Las almacenaremos como secretos en GitHub Actions.

## 2.2 Almacenar claves como secretos en GitHub Actions

1. Ve a **Pipelines** > **Library** > grupo de variables `devsecops-workshop-secrets`
2. Agrega las siguientes variables:

| Variable | Valor | Tipo |
|----------|-------|------|
| `COSIGN_KEY` | Contenido de `cosign.key` (base64 encoded) | Secreto |
| `COSIGN_PASSWORD` | Password que usaste al generar las claves | Secreto |
| `COSIGN_PUB` | Contenido de `cosign.pub` | Normal |

Para codificar la clave privada en base64:

```bash title="Codificar clave en base64"
# Codificar la clave privada
cat cosign.key | base64 -w 0 > cosign.key.b64

# Copiar el contenido y pegarlo en GitHub Actions
cat cosign.key.b64

# La clave publica se puede almacenar tal cual
cat cosign.pub
```

!!! tip "Alternativa: GitHub Secrets"
    En produccion, es mejor almacenar las claves en GitHub Secrets y referenciarlas desde el pipeline con una tarea de Key Vault. Para el workshop usamos variables de grupo por simplicidad.

## 2.3 Agregar la firma al pipeline

Agrega los siguientes steps al job del stage `ImageScan`, **despues** del gate de Trivy:

```yaml title="vulnerable-app/.github/workflows/devsecops.yml -- Steps de Cosign (dentro de ImageScan)"
          # ============================================================
          # Cosign: Firma de imagen
          # ============================================================

          # --- Instalar Cosign ---
          - script: |
              echo "=== Instalando Cosign ==="
              COSIGN_VERSION="v2.2.4"
              curl -fsSL "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64" \
                -o /usr/local/bin/cosign
              chmod +x /usr/local/bin/cosign
              cosign version
            name: 'Instalar Cosign'

          # --- Decodificar clave privada ---
          - script: |
              echo "=== Preparando clave de firma ==="
              echo "$(COSIGN_KEY)" | base64 -d > $(Agent.TempDirectory)/cosign.key
              echo "Clave privada preparada"
            name: 'Preparar clave Cosign'
            env:
              COSIGN_KEY: $(COSIGN_KEY)

          # --- Firmar la imagen ---
          - script: |
              echo "=== Firmando imagen en GHCR ==="
              echo "Imagen: $(imageRef)"

              COSIGN_PASSWORD="$(COSIGN_PASSWORD)" cosign sign \
                --key $(Agent.TempDirectory)/cosign.key \
                --yes \
                $(imageRef)

              echo ""
              echo "=== Imagen firmada exitosamente ==="
              echo "La firma se almaceno junto a la imagen en GHCR"
            name: 'Cosign Sign'
            env:
              COSIGN_PASSWORD: $(COSIGN_PASSWORD)

          # --- Verificar la firma inmediatamente ---
          - script: |
              echo "=== Verificando firma de la imagen ==="

              cosign verify \
                --key $(Agent.TempDirectory)/cosign.key \
                $(imageRef)

              echo ""
              echo "=== Firma verificada correctamente ==="
            name: 'Cosign Verify (post-firma)'
            env:
              COSIGN_PASSWORD: $(COSIGN_PASSWORD)

          # --- Limpiar clave privada ---
          - script: |
              rm -f $(Agent.TempDirectory)/cosign.key
              echo "Clave privada eliminada del agente"
            name: 'Limpiar clave privada'
            if: always()
```

## 2.4 Stage completo (referencia)

Para referencia, asi queda el stage `ImageScan` completo con Trivy y Cosign:

```yaml title="vulnerable-app/.github/workflows/devsecops.yml -- Stage ImageScan completo"
  - stage: ImageScan
    name: 'Image Scan + Signing'
    dependsOn: Build
    variables:
      imageRef: '$(GHCR_LOGIN_SERVER)/workshop-app:${{ github.run_number }}'
    jobs:
      - job: TrivyImageScan
        name: 'Trivy Image Scan + Cosign'
        steps:
          # --- Login GHCR ---
          - uses: docker/login-action@v3
            name: 'Login en GHCR'
            inputs:
              command: login
              containerRegistry: 'acr-service-connection'

          - script: |
              docker pull $(imageRef)
            name: 'Pull imagen desde GHCR'

          # --- Trivy ---
          - script: |
              sudo apt-get install -y wget apt-transport-https gnupg lsb-release
              wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | \
                gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
              echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb \
                $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
              sudo apt-get update && sudo apt-get install -y trivy
            name: 'Instalar Trivy'

          - script: |
              trivy image --severity CRITICAL,HIGH --format table $(imageRef)
            name: 'Trivy Scan (tabla)'
            continue-on-error: true

          - script: |
              trivy image --severity CRITICAL,HIGH --format json \
                --output ${{ github.workspace }}/artifacts/trivy-image-report.json \
                $(imageRef)
            name: 'Trivy Scan (JSON)'
            continue-on-error: true

          - script: |
              trivy image --severity CRITICAL,HIGH --exit-code 1 --format table $(imageRef)
            name: 'Trivy Gate (CRITICAL,HIGH)'
            continue-on-error: true

          - uses: actions/upload-artifact@v4
            name: 'Publicar reporte Trivy Image'
            inputs:
              PathtoPublish: '${{ github.workspace }}/artifacts/trivy-image-report.json'
              ArtifactName: 'trivy-image-report'
              publishLocation: 'Container'
            if: always()

          # --- Cosign ---
          - script: |
              COSIGN_VERSION="v2.2.4"
              curl -fsSL "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64" \
                -o /usr/local/bin/cosign
              chmod +x /usr/local/bin/cosign
              cosign version
            name: 'Instalar Cosign'

          - script: |
              echo "$(COSIGN_KEY)" | base64 -d > $(Agent.TempDirectory)/cosign.key
            name: 'Preparar clave Cosign'
            env:
              COSIGN_KEY: $(COSIGN_KEY)

          - script: |
              COSIGN_PASSWORD="$(COSIGN_PASSWORD)" cosign sign \
                --key $(Agent.TempDirectory)/cosign.key \
                --yes \
                $(imageRef)
              echo "Imagen firmada: $(imageRef)"
            name: 'Cosign Sign'
            env:
              COSIGN_PASSWORD: $(COSIGN_PASSWORD)

          - script: |
              cosign verify \
                --key $(Agent.TempDirectory)/cosign.key \
                $(imageRef)
            name: 'Cosign Verify (post-firma)'
            env:
              COSIGN_PASSWORD: $(COSIGN_PASSWORD)

          - script: |
              rm -f $(Agent.TempDirectory)/cosign.key
            name: 'Limpiar clave privada'
            if: always()
```

## 2.5 Que ocurre durante la firma

Cuando Cosign firma una imagen:

1. **Calcula el digest** de la imagen (SHA256)
2. **Firma el digest** con la clave privada
3. **Sube la firma** al registro como un artefacto OCI adjunto
4. La firma queda almacenada junto a la imagen en GHCR con el tag `sha256-<digest>.sig`

```text title="Artefactos en GHCR despues de la firma"
ghcr.io/entelgy/workshop-app
  - Tag: 42          (imagen)
  - Tag: sha256-abc123...sig  (firma de Cosign)
```

!!! info "Firmas transparentes con Sigstore"
    Cosign tambien soporta firma "keyless" usando Sigstore Rekor (un log de transparencia publico). En un entorno enterprise, las claves locales ofrecen mas control. Para proyectos open source, la firma keyless con OIDC es mas conveniente.

## 2.6 Verificar en GitHub Actions

1. Haz commit y push de los cambios
2. Observa el pipeline -- los steps de Cosign se ejecutan despues de Trivy
3. En los logs de "Cosign Sign" deberias ver:

```text
Pushing signature to: ghcr.io/entelgy/workshop-app
```

4. En Azure Portal > GHCR > Repositorios, veras el tag de firma junto al tag de la imagen

!!! success "Paso Completado"
    Has firmado la imagen de contenedor con Cosign. Solo las imagenes que pasan el escaneo de Trivy son firmadas, y la firma queda almacenada en GHCR para verificacion posterior.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="step1.md" class="md-button">Anterior: Escaneo con Trivy</a>
  <a href="step3.md" class="md-button md-button--primary">Siguiente: Verificacion de Firmas</a>
</div>
