---
tags:
  - lab
  - trivy
  - container-security
---

# Paso 1 -- Escaneo de Imagen con Trivy

!!! abstract "Objetivo"
    Agregar un paso al pipeline de GitHub Actions que escanee la imagen de contenedor almacenada en GHCR con Trivy, configurando un gate que bloquee el pipeline si se encuentran vulnerabilidades CRITICAL o HIGH.

## Contexto

En el Lab 5 usamos Trivy para escanear el sistema de archivos (modo `fs`) y las dependencias. Ahora usaremos Trivy en modo `image` para escanear la imagen de contenedor completa, incluyendo:

- Paquetes del sistema operativo base (Debian/Alpine)
- Librerias de aplicacion instaladas con pip
- Configuraciones inseguras en las capas de la imagen

## 1.1 Entender Trivy Image Scan

Trivy en modo `image` analiza todas las capas de una imagen de contenedor. A diferencia del escaneo `fs`, este modo detecta vulnerabilidades en:

| Capa | Ejemplo | Tipo de CVE |
|------|---------|-------------|
| SO base | `python:3.11-slim-bookworm` | CVEs de Debian (libc, openssl, etc.) |
| Paquetes del sistema | Paquetes del sistema heredados | CVEs de paquetes del sistema |
| Dependencias de app | Flask, Jinja2, Werkzeug | CVEs de PyPI |
| Configuracion | Puertos expuestos, USER root | Misconfigurations |

!!! tip "Trivy image vs Trivy fs"
    El escaneo `trivy image` requiere acceso a la imagen (local o en un registro). Por eso lo ejecutamos **despues** del stage de Build que sube la imagen a GHCR.

## 1.2 Probar localmente (opcional)

Antes de integrar en el pipeline, puedes probar el escaneo localmente:

```bash title="Escaneo local de la imagen"
# Construir la imagen localmente
cd vulnerable-app/
docker build -t workshop-app:local .

# Escanear con Trivy
trivy image --severity CRITICAL,HIGH workshop-app:local
```

Salida esperada (fragmento):

```text title="Salida de Trivy Image (ejemplo)"
workshop-app:local (debian 12.5)

Total: 24 (CRITICAL: 3, HIGH: 21)

+-----------------+------------------+----------+-------------------+---------------+
|     Library     |  Vulnerability   | Severity | Installed Version | Fixed Version |
+-----------------+------------------+----------+-------------------+---------------+
| libssl3         | CVE-2024-5535    | CRITICAL | 3.0.11-1~deb12u2  | 3.0.14-1      |
| libexpat1       | CVE-2024-45490   | CRITICAL | 2.5.0-1           | 2.5.0-1+deb12 |
| zlib1g          | CVE-2023-45853   | HIGH     | 1:1.2.13-1        |               |
| pip             | CVE-2023-5752    | HIGH     | 23.0.1            | 23.3          |
+-----------------+------------------+----------+-------------------+---------------+

Python (pip)

Total: 5 (CRITICAL: 1, HIGH: 4)

+-----------------+------------------+----------+-------------------+---------------+
|     Library     |  Vulnerability   | Severity | Installed Version | Fixed Version |
+-----------------+------------------+----------+-------------------+---------------+
| Werkzeug        | CVE-2024-34069   | CRITICAL | 2.3.0             | 3.0.3         |
| Jinja2          | CVE-2024-34064   | HIGH     | 3.1.2             | 3.1.4         |
| Flask           | CVE-2023-30861   | HIGH     | 2.3.2             | 2.3.3         |
+-----------------+------------------+----------+-------------------+---------------+
```

!!! warning "Imagen vulnerable por diseno"
    La imagen construida desde `vulnerable-app/Dockerfile` usa `python:latest` con `USER root` y paquetes innecesarios. Esto genera muchas vulnerabilidades. La imagen construida desde `Dockerfile.secure` tendra significativamente menos hallazgos.

## 1.3 Agregar el stage ImageScan al pipeline

Abre `vulnerable-app/.github/workflows/devsecops.yml` y agrega el stage `ImageScan` despues del stage `Build`:

```yaml title="vulnerable-app/.github/workflows/devsecops.yml -- Stage ImageScan"
  # ============================================================
  # Lab 7: Escaneo de Imagen con Trivy + Firma con Cosign
  # ============================================================
  - stage: ImageScan
    name: 'Image Scan + Signing'
    dependsOn: Build
    variables:
      imageRef: '$(GHCR_LOGIN_SERVER)/workshop-app:${{ github.run_number }}'
    jobs:
      - job: TrivyImageScan
        name: 'Trivy Image Scan'
        steps:
          # --- Autenticar contra GHCR para pull de la imagen ---
          - uses: docker/login-action@v3
            name: 'Login en GHCR'
            inputs:
              command: login
              containerRegistry: 'acr-service-connection'

          # --- Pull de la imagen desde GHCR ---
          - script: |
              echo "=== Descargando imagen desde GHCR ==="
              docker pull $(imageRef)
              echo "Imagen descargada: $(imageRef)"
            name: 'Pull imagen desde GHCR'

          # --- Instalar Trivy ---
          - script: |
              echo "=== Instalando Trivy ==="
              sudo apt-get install -y wget apt-transport-https gnupg lsb-release
              wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | \
                gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
              echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb \
                $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
              sudo apt-get update
              sudo apt-get install -y trivy
              trivy --version
            name: 'Instalar Trivy'

          # --- Escaneo de imagen: tabla para logs ---
          - script: |
              echo "=== Escaneo de vulnerabilidades de imagen ==="
              echo "Imagen: $(imageRef)"
              echo ""

              trivy image \
                --severity CRITICAL,HIGH \
                --format table \
                $(imageRef)

              echo ""
              echo "=== Escaneo de tabla completado ==="
            name: 'Trivy Scan (tabla informativa)'
            continue-on-error: true

          # --- Escaneo de imagen: JSON para artefacto ---
          - script: |
              trivy image \
                --severity CRITICAL,HIGH \
                --format json \
                --output ${{ github.workspace }}/artifacts/trivy-image-report.json \
                $(imageRef)

              echo "Reporte JSON generado"
            name: 'Trivy Scan (JSON report)'
            continue-on-error: true

          # --- Escaneo de imagen: GATE (falla el pipeline) ---
          - script: |
              echo "=== Gate de seguridad: CRITICAL + HIGH ==="

              trivy image \
                --severity CRITICAL,HIGH \
                --exit-code 1 \
                --format table \
                $(imageRef)

              if [ $? -eq 0 ]; then
                echo "Sin vulnerabilidades CRITICAL/HIGH encontradas"
              fi
            name: 'Trivy Gate (CRITICAL,HIGH)'
            continue-on-error: true  # Cambiar a false para bloquear

          # --- Publicar reporte como artefacto ---
          - uses: actions/upload-artifact@v4
            name: 'Publicar reporte Trivy Image'
            inputs:
              PathtoPublish: '${{ github.workspace }}/artifacts/trivy-image-report.json'
              ArtifactName: 'trivy-image-report'
              publishLocation: 'Container'
            if: always()
```

!!! info "continue-on-error: true"
    Durante el workshop dejamos `continue-on-error: true` en el gate para que el pipeline continue y podamos ver todos los stages. En un entorno real, cambiarias esto a `false` para que el pipeline se detenga si se encuentran vulnerabilidades criticas.

## 1.4 Entender la configuracion del gate

El parametro clave es `--exit-code 1`:

| Parametro | Valor | Efecto |
|-----------|-------|--------|
| `--severity` | `CRITICAL,HIGH` | Solo reporta estas severidades |
| `--exit-code` | `1` | Retorna exit code 1 si encuentra vulnerabilidades |
| `--format` | `table` | Formato legible para los logs |
| `--format` | `json` | Formato estructurado para artefactos |

!!! tip "Ajustar el gate progresivamente"
    En las primeras iteraciones puedes usar solo `--severity CRITICAL`. Conforme el equipo madure, agrega `HIGH` y eventualmente `MEDIUM`. Nunca intentes corregir todo de golpe.

## 1.5 Analizar los hallazgos esperados

Dado que nuestra imagen usa `python:latest` (Dockerfile vulnerable), esperamos encontrar:

**Vulnerabilidades del SO base:**

- CVEs en `openssl`/`libssl` -- la imagen `latest` rara vez esta parcheada
- CVEs en `libc6` / `glibc` -- comunes en Debian
- CVEs en herramientas innecesarias (`curl`, `vim`, `wget`, `netcat-openbsd`)

**Vulnerabilidades de aplicacion:**

- CVEs en `Werkzeug`, `Jinja2`, `Flask` -- dependencias desactualizadas
- CVEs en `pip` -- version antigua

**Misconfiguraciones:**

- `USER root` -- la imagen corre como root
- Puerto 22 expuesto (SSH en un contenedor)

!!! warning "Comparacion: Dockerfile vs Dockerfile.secure"
    Si reconstruyes la imagen con `Dockerfile.secure` (del Lab 6), veras una reduccion significativa de CVEs. La imagen segura usa `python:3.11-slim-bookworm`, no instala herramientas innecesarias y corre como usuario no-root.

## 1.6 Verificar en GitHub Actions

1. Haz commit y push de los cambios a `.github/workflows/devsecops.yml`
2. Ve a **Pipelines** > tu pipeline > ultimo run
3. Observa el stage **Image Scan + Signing**
4. Revisa los logs del job **Trivy Image Scan**
5. Descarga el artefacto `trivy-image-report` y revisa el JSON

!!! success "Paso Completado"
    Has agregado el escaneo de imagen con Trivy al pipeline. La imagen se analiza despues del build y antes de la firma, creando un gate de seguridad que puede bloquear imagenes vulnerables.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="index.md" class="md-button">Anterior: Introduccion</a>
  <a href="step2.md" class="md-button md-button--primary">Siguiente: Firma con Cosign</a>
</div>
