---
tags:
  - lab
  - gitleaks
  - pipeline
  - sarif
---

# Paso 2 -- Añadir Stage al Pipeline

!!! abstract "Objetivo"
    Implementar el stage `SecretsDetection` en `azure-pipelines.yml` usando Gitleaks en un contenedor Docker, configurar para que falle si detecta secretos y publicar el reporte SARIF como artefacto del pipeline.

## 2.1 Reemplazar el placeholder de SecretsDetection

Abre `azure-pipelines.yml` y reemplaza el stage `SecretsDetection` completo con la implementacion real:

```yaml title="azure-pipelines.yml — stage SecretsDetection"
  # ──────────────────────────────────────────────
  # Stage 1: Deteccion de Secretos (Gitleaks)
  # ──────────────────────────────────────────────
  - stage: SecretsDetection
    displayName: 'Deteccion de Secretos'
    jobs:
      - job: Gitleaks
        displayName: 'Gitleaks - Escaneo de Secretos'
        steps:
          - checkout: self
            fetchDepth: 0
            displayName: 'Checkout completo (historial)'

          - script: |
              echo "=== Gitleaks — Deteccion de Secretos ==="
              echo "Directorio: $(appDirectory)"
              echo "Commit: $(Build.SourceVersion)"
              echo ""

              docker run --rm \
                -v "$(Build.SourcesDirectory):/src" \
                ghcr.io/gitleaks/gitleaks:latest \
                detect \
                --source /src/$(appDirectory) \
                --no-git \
                --config /src/$(appDirectory)/.gitleaks.toml \
                --report-format sarif \
                --report-path /src/gitleaks-report.sarif \
                --verbose \
                --exit-code 1

              GITLEAKS_EXIT=$?

              echo ""
              echo "Gitleaks exit code: $GITLEAKS_EXIT"

              if [ $GITLEAKS_EXIT -ne 0 ]; then
                echo "##[error]Gitleaks detecto secretos en el codigo!"
                echo "Revisa el reporte SARIF en los artefactos del pipeline."
              else
                echo "No se detectaron secretos."
              fi

              exit $GITLEAKS_EXIT
            displayName: 'Ejecutar Gitleaks'
            continueOnError: false

          - task: PublishBuildArtifacts@1
            displayName: 'Publicar reporte SARIF'
            inputs:
              PathtoPublish: '$(Build.SourcesDirectory)/gitleaks-report.sarif'
              ArtifactName: 'SecurityReports-Gitleaks'
              publishLocation: 'Container'
            condition: always()
```

## 2.2 Analizar la configuracion

### Checkout con historial completo

```yaml
- checkout: self
  fetchDepth: 0
```

`fetchDepth: 0` descarga el historial completo de git. Esto permite que Gitleaks escanee no solo los archivos actuales, sino tambien commits anteriores donde se pudieron haber introducido (y despues borrado) secretos.

!!! warning "fetchDepth"
    Si usas `fetchDepth: 1` (shallow clone, que es el default), Gitleaks solo vera los archivos en su estado actual. Secretos que fueron agregados y luego eliminados en commits anteriores **no seran detectados**. Siempre usa `fetchDepth: 0` para deteccion de secretos.

### Ejecucion via Docker

```bash
docker run --rm \
  -v "$(Build.SourcesDirectory):/src" \
  ghcr.io/gitleaks/gitleaks:latest \
  detect \
  --source /src/$(appDirectory) \
  --no-git \
  --config /src/$(appDirectory)/.gitleaks.toml \
  --report-format sarif \
  --report-path /src/gitleaks-report.sarif \
  --verbose \
  --exit-code 1
```

| Parametro | Descripcion |
|-----------|-------------|
| `--rm` | Elimina el contenedor al terminar |
| `-v "...:/src"` | Monta el codigo fuente en `/src` dentro del contenedor |
| `--source /src/$(appDirectory)` | Directorio a escanear |
| `--no-git` | Escanear archivos, no historial git (usamos `detect` sin git por ahora) |
| `--config` | Usar la configuracion personalizada con reglas de Entelgy |
| `--report-format sarif` | Generar reporte en formato SARIF |
| `--report-path` | Ruta donde se guarda el reporte |
| `--exit-code 1` | Salir con codigo 1 si encuentra secretos (falla el pipeline) |

### Publicacion del artefacto

```yaml
- task: PublishBuildArtifacts@1
  condition: always()
```

`condition: always()` asegura que el reporte SARIF se publique **incluso si** Gitleaks falla (que es exactamente cuando mas lo necesitamos). Sin esta condicion, el step se omitiria al fallar el step anterior.

## 2.3 Pipeline YAML actualizado completo

Para referencia, asi queda la parte inicial del pipeline despues de este cambio:

```yaml title="azure-pipelines.yml (inicio)"
trigger:
  branches:
    include:
      - main
  paths:
    exclude:
      - 'docs/**'
      - '*.md'

pool:
  vmImage: 'ubuntu-latest'

variables:
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
  - group: devsecops-workshop-secrets

stages:
  # Stage 1: SecretsDetection (implementado arriba)
  # Stage 2-10: permanecen como placeholders
```

## 2.4 Hacer push y observar el resultado

```bash title="Terminal"
git add azure-pipelines.yml
git commit -m "lab03: implementar stage SecretsDetection con Gitleaks"
git push origin main
```

Ve a Azure DevOps y observa la ejecucion:

1. El stage **SecretsDetection** deberia **fallar** con codigo de salida 1
2. Los logs mostraran los secretos encontrados
3. Los stages posteriores (SAST, SCA, etc.) se **omitiran** automaticamente
4. En la seccion **Artifacts**, veras `SecurityReports-Gitleaks`

!!! warning "El pipeline va a fallar"
    Esto es **esperado y correcto**. Gitleaks esta detectando los secretos que intencionalmente plantamos en `vulnerable-app/`. En un pipeline real, este comportamiento evita que codigo con secretos llegue a produccion.

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

Para poder seguir con los labs siguientes mientras los secretos siguen en el codigo, puedes usar `continueOnError: true` temporalmente:

```yaml title="Opcion temporal"
          - script: |
              docker run --rm \
                -v "$(Build.SourcesDirectory):/src" \
                ghcr.io/gitleaks/gitleaks:latest \
                detect \
                --source /src/$(appDirectory) \
                --no-git \
                --config /src/$(appDirectory)/.gitleaks.toml \
                --report-format sarif \
                --report-path /src/gitleaks-report.sarif \
                --verbose \
                --exit-code 1 || true
            displayName: 'Ejecutar Gitleaks (no-blocking)'
```

!!! warning "Solo para el workshop"
    Agregar `|| true` al final del comando permite que el pipeline continue aunque Gitleaks detecte secretos. **Nunca hagas esto en un pipeline de produccion**. Aqui lo usamos solo para poder avanzar con los demas labs.

!!! success "Paso Completado"
    El stage SecretsDetection esta implementado en el pipeline. Gitleaks se ejecuta en Docker, detecta secretos, genera un reporte SARIF y falla el pipeline correctamente.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../step1/" class="md-button">Anterior: Paso 1</a>
  <a href="../step3/" class="md-button md-button--primary">Paso 3: Probar y Remediar</a>
</div>
