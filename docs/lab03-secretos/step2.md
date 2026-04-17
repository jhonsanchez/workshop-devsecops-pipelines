---
tags:
  - lab
  - gitleaks
  - pipeline
  - sarif
---

# Paso 2 -- Añadir Job al Workflow

!!! abstract "Objetivo"
    Implementar el job `secrets-detection` en `.github/workflows/devsecops.yml` usando Gitleaks en un contenedor Docker, configurar para que falle si detecta secretos y publicar el reporte SARIF como artefacto del workflow.

## 2.1 Reemplazar el placeholder de secrets-detection

Abre `.github/workflows/devsecops.yml` y reemplaza el job `secrets-detection` completo con la implementacion real:

```yaml title=".github/workflows/devsecops.yml — job secrets-detection"
  # ──────────────────────────────────────────────
  # Job 1: Deteccion de Secretos (Gitleaks)
  # ──────────────────────────────────────────────
  secrets-detection:
    name: 'Deteccion de Secretos'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
        name: 'Checkout completo (historial)'

      - run: |
          echo "=== Gitleaks — Deteccion de Secretos ==="
          echo "Directorio: ${{ env.APP_DIRECTORY }}"
          echo "Commit: ${{ github.sha }}"
          echo ""

          docker run --rm \
            -v "${{ github.workspace }}:/src" \
            ghcr.io/gitleaks/gitleaks:latest \
            detect \
            --source /src/${{ env.APP_DIRECTORY }} \
            --no-git \
            --config /src/${{ env.APP_DIRECTORY }}/.gitleaks.toml \
            --report-format sarif \
            --report-path /src/gitleaks-report.sarif \
            --verbose \
            --exit-code 1

          GITLEAKS_EXIT=$?

          echo ""
          echo "Gitleaks exit code: $GITLEAKS_EXIT"

          if [ $GITLEAKS_EXIT -ne 0 ]; then
            echo "::error::Gitleaks detecto secretos en el codigo!"
            echo "Revisa el reporte SARIF en los artefactos del workflow."
          else
            echo "No se detectaron secretos."
          fi

          exit $GITLEAKS_EXIT
        name: 'Ejecutar Gitleaks'

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: SecurityReports-Gitleaks
          path: gitleaks-report.sarif
        name: 'Publicar reporte SARIF'
```

## 2.2 Analizar la configuracion

### Checkout con historial completo

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
```

`fetch-depth: 0` descarga el historial completo de git. Esto permite que Gitleaks escanee no solo los archivos actuales, sino tambien commits anteriores donde se pudieron haber introducido (y despues borrado) secretos.

!!! warning "fetch-depth"
    Si usas `fetch-depth: 1` (shallow clone, que es el default en GitHub Actions), Gitleaks solo vera los archivos en su estado actual. Secretos que fueron agregados y luego eliminados en commits anteriores **no seran detectados**. Siempre usa `fetch-depth: 0` para deteccion de secretos.

### Ejecucion via Docker

```bash
docker run --rm \
  -v "${{ github.workspace }}:/src" \
  ghcr.io/gitleaks/gitleaks:latest \
  detect \
  --source /src/${{ env.APP_DIRECTORY }} \
  --no-git \
  --config /src/${{ env.APP_DIRECTORY }}/.gitleaks.toml \
  --report-format sarif \
  --report-path /src/gitleaks-report.sarif \
  --verbose \
  --exit-code 1
```

| Parametro | Descripcion |
|-----------|-------------|
| `--rm` | Elimina el contenedor al terminar |
| `-v "...:/src"` | Monta el codigo fuente en `/src` dentro del contenedor |
| `--source /src/${{ env.APP_DIRECTORY }}` | Directorio a escanear |
| `--no-git` | Escanear archivos, no historial git (usamos `detect` sin git por ahora) |
| `--config` | Usar la configuracion personalizada con reglas de Entelgy |
| `--report-format sarif` | Generar reporte en formato SARIF |
| `--report-path` | Ruta donde se guarda el reporte |
| `--exit-code 1` | Salir con codigo 1 si encuentra secretos (falla el pipeline) |

### Publicacion del artefacto

```yaml
- uses: actions/upload-artifact@v4
  if: always()
```

`if: always()` asegura que el reporte SARIF se publique **incluso si** Gitleaks falla (que es exactamente cuando mas lo necesitamos). Sin esta condicion, el step se omitiria al fallar el step anterior.

## 2.3 Pipeline YAML actualizado completo

Para referencia, asi queda la parte inicial del pipeline despues de este cambio:

```yaml title=".github/workflows/devsecops.yml (inicio)"
name: DevSecOps Pipeline

on:
  push:
    branches:
      - main
    paths-ignore:
      - 'docs/**'
      - '*.md'

env:
  IMAGE_NAME: 'vulnerable-app'
  IMAGE_TAG: ${{ github.run_number }}
  REGISTRY: 'ghcr.io'
  REGISTRY_URL: 'ghcr.io/${{ github.repository_owner }}'
  DOCKERFILE_PATH: 'vulnerable-app/Dockerfile.secure'
  APP_DIRECTORY: 'vulnerable-app'

jobs:
  # Job 1: secrets-detection (implementado arriba)
  # Job 2-10: permanecen como placeholders
```

## 2.4 Hacer push y observar el resultado

```bash title="Terminal"
git add .github/workflows/devsecops.yml
git commit -m "lab03: implementar job secrets-detection con Gitleaks"
git push origin main
```

Ve a GitHub > **Actions** y observa la ejecucion:

1. El job **Deteccion de Secretos** deberia **fallar** con codigo de salida 1
2. Los logs mostraran los secretos encontrados
3. Los jobs posteriores (sast, sca, etc.) se **omitiran** automaticamente
4. En la seccion **Artifacts**, veras `SecurityReports-Gitleaks`

!!! warning "El workflow va a fallar"
    Esto es **esperado y correcto**. Gitleaks esta detectando los secretos que intencionalmente plantamos en `vulnerable-app/`. En un workflow real, este comportamiento evita que codigo con secretos llegue a produccion.

## 2.5 Descargar y revisar el reporte SARIF

1. En el detalle del run, haz clic en **Artifacts**
2. Descarga `SecurityReports-Gitleaks`
3. Abre el archivo `gitleaks-report.sarif` con un editor de texto

El SARIF contiene una estructura JSON con:

```json title="Fragmento de gitleaks-report.sarif"
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "gitleaks",
          "semanticVersion": "8.x.x"
        }
      },
      "results": [
        {
          "ruleId": "aws-access-token",
          "message": {
            "text": "AWS Access Token detected"
          },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": {
                  "uri": ".env.example"
                },
                "region": {
                  "startLine": 3
                }
              }
            }
          ]
        }
      ]
    }
  ]
}
```

!!! tip "SARIF en VS Code"
    Puedes instalar la extension **SARIF Viewer** en VS Code para visualizar los reportes SARIF de forma interactiva, con enlaces directos a las lineas de codigo afectadas.

## 2.6 Permitir continuar temporalmente (opcional)

Para poder seguir con los labs siguientes mientras los secretos siguen en el codigo, puedes usar `continue-on-error: true` temporalmente:

```yaml title="Opcion temporal"
      - run: |
          docker run --rm \
            -v "${{ github.workspace }}:/src" \
            ghcr.io/gitleaks/gitleaks:latest \
            detect \
            --source /src/${{ env.APP_DIRECTORY }} \
            --no-git \
            --config /src/${{ env.APP_DIRECTORY }}/.gitleaks.toml \
            --report-format sarif \
            --report-path /src/gitleaks-report.sarif \
            --verbose \
            --exit-code 1 || true
        name: 'Ejecutar Gitleaks (no-blocking)'
```

!!! warning "Solo para el workshop"
    Agregar `|| true` al final del comando permite que el workflow continue aunque Gitleaks detecte secretos. **Nunca hagas esto en un workflow de produccion**. Aqui lo usamos solo para poder avanzar con los demas labs.

!!! success "Paso Completado"
    El job secrets-detection esta implementado en el workflow. Gitleaks se ejecuta en Docker, detecta secretos, genera un reporte SARIF y falla el workflow correctamente.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../step1/" class="md-button">Anterior: Paso 1</a>
  <a href="../step3/" class="md-button md-button--primary">Paso 3: Probar y Remediar</a>
</div>
