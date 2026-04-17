---
tags:
  - lab
  - checkov
  - pipeline
  - sarif
---

# Paso 2 -- Stage IaC en el Pipeline

!!! abstract "Objetivo"
    Agregar el stage `IaCScan` al pipeline de GitHub Actions usando Checkov en Docker, configurar el gate para fallar en vulnerabilidades CRITICAL, y publicar el reporte SARIF como artefacto.

## 2.1 Agregar el stage IaCScan

Abre `vulnerable-app/.github/workflows/devsecops.yml` y agrega el stage `IaCScan` despues del stage `DAST`:

```yaml title="vulnerable-app/.github/workflows/devsecops.yml -- Stage IaCScan"
  # ============================================================
  # Lab 9: Escaneo de IaC con Checkov + Conftest
  # ============================================================
  - stage: IaCScan
    name: 'IaC Scan — Checkov + Conftest'
    dependsOn: DAST
    jobs:
      - job: CheckovScan
        name: 'Checkov Terraform Scan'
        steps:
          - checkout: self

          # --- Escaneo con Checkov (tabla para logs) ---
          - script: |
              echo "=== Checkov: Escaneo de Terraform ==="
              echo "Directorio: vulnerable-app/infrastructure/"
              echo ""

              docker run --rm \
                -v ${{ github.workspace }}/vulnerable-app/infrastructure:/tf:ro \
                -w /tf \
                bridgecrew/checkov \
                  -d /tf \
                  --framework terraform \
                  --output cli \
                  --compact

              echo ""
              echo "=== Escaneo de tabla completado ==="
            name: 'Checkov Scan (tabla informativa)'
            continue-on-error: true

          # --- Escaneo con Checkov: reporte JSON ---
          - script: |
              echo "=== Generando reporte JSON ==="

              docker run --rm \
                -v ${{ github.workspace }}/vulnerable-app/infrastructure:/tf:ro \
                -v ${{ github.workspace }}/artifacts:/output \
                -w /tf \
                bridgecrew/checkov \
                  -d /tf \
                  --framework terraform \
                  --output json \
                  --output-file-path /output

              echo "Reporte JSON generado"
              ls -la ${{ github.workspace }}/artifacts/
            name: 'Checkov Scan (JSON)'
            continue-on-error: true

          # --- Escaneo con Checkov: reporte SARIF ---
          - script: |
              echo "=== Generando reporte SARIF ==="

              docker run --rm \
                -v ${{ github.workspace }}/vulnerable-app/infrastructure:/tf:ro \
                -v ${{ github.workspace }}/artifacts:/output \
                -w /tf \
                bridgecrew/checkov \
                  -d /tf \
                  --framework terraform \
                  --output sarif \
                  --output-file-path /output

              echo "Reporte SARIF generado"
            name: 'Checkov Scan (SARIF)'
            continue-on-error: true

          # --- Gate: Fallar en checks de severidad HIGH ---
          - script: |
              echo "=== Gate IaC: Severidad HIGH ==="

              docker run --rm \
                -v ${{ github.workspace }}/vulnerable-app/infrastructure:/tf:ro \
                -w /tf \
                bridgecrew/checkov \
                  -d /tf \
                  --framework terraform \
                  --check-severity HIGH \
                  --compact

              EXIT_CODE=$?
              if [ $EXIT_CODE -ne 0 ]; then
                echo ""
                echo "::warning::Checkov encontro misconfiguraciones de severidad HIGH"
                echo "Revisa el reporte para detalles"
                # Descomentar para bloquear:
                # exit 1
              fi
            name: 'Checkov Gate (HIGH severity)'
            continue-on-error: true

          # --- Publicar reportes ---
          - uses: actions/upload-artifact@v4
            name: 'Publicar reportes Checkov'
            inputs:
              PathtoPublish: '${{ github.workspace }}/artifacts'
              ArtifactName: 'checkov-reports'
              publishLocation: 'Container'
            if: always()
```

## 2.2 Entender la configuracion de Checkov en Docker

| Parametro | Valor | Descripcion |
|-----------|-------|-------------|
| `-v .../infrastructure:/tf:ro` | Volume mount read-only | Monta el directorio Terraform sin poder modificarlo |
| `-d /tf` | Directorio a escanear | Ruta dentro del contenedor |
| `--framework terraform` | Solo Terraform | Evita escanear otros tipos de archivos |
| `--output cli` | Formato tabla | Legible en los logs |
| `--output json` | Formato JSON | Para procesamiento automatizado |
| `--output sarif` | Formato SARIF | Para integracion con herramientas |
| `--check-severity HIGH` | Solo HIGH | Filtrar checks por severidad |
| `--compact` | Salida compacta | Menos verboso para los logs |

## 2.3 Configurar archivo .checkov.yml

Puedes crear un archivo de configuracion para Checkov que se aplique automaticamente:

```yaml title="vulnerable-app/infrastructure/.checkov.yml"
# Checkov configuration
# Referencia: https://www.checkov.io/2.Basics/CLI%20Command%20Reference.html

# Frameworks a escanear
framework:
  - terraform

# Formato de salida
output:
  - cli

# Compactar salida
compact: true

# Checks a saltar (falsos positivos confirmados)
skip-check:
  # - CKV2_AZURE_tag  # Descomentar si no usas tags en el workshop

# Severidad minima para reportar
# check-severity: HIGH

# Directorio a escanear
directory:
  - .
```

!!! tip "Archivo de configuracion vs parametros CLI"
    El archivo `.checkov.yml` es util para mantener la configuracion versionada. Los parametros CLI sobreescriben la configuracion del archivo.

## 2.4 Integrar SARIF con GitHub Actions

El formato SARIF permite visualizar los resultados directamente en GitHub Actions. Agrega este paso para publicar los resultados:

```yaml title="Publicar SARIF en GitHub Actions (opcional)"
          # --- Publicar SARIF (requiere extension SARIF Viewer) ---
          - uses: actions/upload-artifact@v4
            name: 'Publicar SARIF'
            inputs:
              PathtoPublish: '${{ github.workspace }}/artifacts/results_sarif.sarif'
              ArtifactName: 'CodeAnalysisLogs'
              publishLocation: 'Container'
            if: always()
```

!!! info "Extension SARIF Viewer"
    Para ver los resultados SARIF directamente en la interfaz de GitHub Actions, instala la extension [SARIF SAST Scans Tab](https://marketplace.visualstudio.com/items?itemName=sariftools.scans) desde el Visual Studio Marketplace.

## 2.5 Excluir checks especificos

En algunos casos necesitaras excluir checks que no aplican a tu contexto:

```yaml title="Checkov con exclusiones"
          - script: |
              docker run --rm \
                -v ${{ github.workspace }}/vulnerable-app/infrastructure:/tf:ro \
                -w /tf \
                bridgecrew/checkov \
                  -d /tf \
                  --framework terraform \
                  --skip-check CKV2_AZURE_tag,CKV2_AZURE_18 \
                  --output cli \
                  --compact
            name: 'Checkov (con exclusiones)'
```

!!! warning "Documentar exclusiones"
    Cada check excluido debe tener una justificacion documentada. Nunca excluyas un check solo porque falla. Usa el archivo `.checkov.yml` con comentarios explicando por que se excluye cada check.

## 2.6 Verificar en GitHub Actions

1. Haz commit y push del pipeline actualizado
2. Ve a **Pipelines** > tu pipeline > ultimo run
3. El stage **IaC Scan** deberia mostrar:
    - Checkov escaneando los archivos Terraform
    - Lista de checks PASSED y FAILED
    - Reportes generados (JSON y SARIF)
4. Descarga el artefacto `checkov-reports` y revisa los resultados

!!! success "Paso Completado"
    Has integrado Checkov en el pipeline. Ahora el Terraform se escanea automaticamente en cada push, y los resultados estan disponibles como artefactos. En el siguiente paso agregaremos politicas personalizadas con OPA/Conftest.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="step1.md" class="md-button">Anterior: Checkov Local</a>
  <a href="step3.md" class="md-button md-button--primary">Siguiente: Politicas OPA</a>
</div>
