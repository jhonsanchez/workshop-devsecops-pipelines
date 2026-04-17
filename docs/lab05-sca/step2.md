---
tags:
  - lab
  - sca
  - trivy
  - pipeline
  - sbom
---

# Paso 2 -- Añadir Stage SCA

!!! abstract "Objetivo"
    Implementar el stage `SCA` en `azure-pipelines.yml` con Trivy fs, configurar un gate de severidad (fallar en HIGH/CRITICAL), generar un SBOM CycloneDX y publicarlo como artefacto del build.

## 2.1 Reemplazar el placeholder de SCA

Abre `azure-pipelines.yml` y reemplaza el stage `SCA` completo:

```yaml title="azure-pipelines.yml — stage SCA"
  # ──────────────────────────────────────────────
  # Stage 3: SCA - Composicion de Software (Trivy)
  # ──────────────────────────────────────────────
  - stage: SCA
    displayName: 'SCA - Dependencias'
    dependsOn: SAST
    jobs:
      - job: TrivyFS
        displayName: 'Trivy FS - Analisis de Dependencias'
        steps:
          - checkout: self
            displayName: 'Checkout del repositorio'

          # --- Paso 1: Escaneo de vulnerabilidades ---
          - script: |
              echo "=== Trivy FS — Analisis de Composicion de Software ==="
              echo "Directorio: $(appDirectory)"
              echo ""

              mkdir -p $(Build.ArtifactStagingDirectory)/sca-reports

              # Escaneo de CVEs en dependencias
              docker run --rm \
                -v "$(Build.SourcesDirectory):/src" \
                -v "$(Build.ArtifactStagingDirectory)/sca-reports:/reports" \
                aquasec/trivy:latest \
                fs /src/$(appDirectory)/ \
                  --severity HIGH,CRITICAL \
                  --exit-code 1 \
                  --format table

              TRIVY_EXIT=$?

              echo ""
              echo "Trivy exit code: $TRIVY_EXIT"

              if [ $TRIVY_EXIT -ne 0 ]; then
                echo "##[warning]Trivy detecto vulnerabilidades HIGH o CRITICAL en las dependencias"
              else
                echo "No se detectaron vulnerabilidades HIGH/CRITICAL."
              fi

              exit $TRIVY_EXIT
            displayName: 'Escanear CVEs en dependencias'
            continueOnError: true

          # --- Paso 2: Generar reporte SARIF ---
          - script: |
              docker run --rm \
                -v "$(Build.SourcesDirectory):/src" \
                -v "$(Build.ArtifactStagingDirectory)/sca-reports:/reports" \
                aquasec/trivy:latest \
                fs /src/$(appDirectory)/ \
                  --format sarif \
                  --output /reports/trivy-sca-report.sarif

              echo "Reporte SARIF generado."
            displayName: 'Generar reporte SARIF'
            condition: always()

          # --- Paso 3: Generar SBOM CycloneDX ---
          - script: |
              docker run --rm \
                -v "$(Build.SourcesDirectory):/src" \
                -v "$(Build.ArtifactStagingDirectory)/sca-reports:/reports" \
                aquasec/trivy:latest \
                fs /src/$(appDirectory)/ \
                  --format cyclonedx \
                  --output /reports/sbom-cyclonedx.json

              echo "SBOM CycloneDX generado."

              # Mostrar resumen del SBOM
              python3 -c "
import json
with open('$(Build.ArtifactStagingDirectory)/sca-reports/sbom-cyclonedx.json') as f:
    sbom = json.load(f)
    components = sbom.get('components', [])
    print(f'')
    print(f'=== SBOM Resumen ===')
    print(f'Formato: {sbom.get(\"bomFormat\")}')
    print(f'Componentes: {len(components)}')
    for c in components:
        print(f'  - {c.get(\"name\")}=={c.get(\"version\", \"?\")}')
"
            displayName: 'Generar SBOM CycloneDX'
            condition: always()

          # --- Paso 4: Publicar artefactos ---
          - task: PublishBuildArtifacts@1
            displayName: 'Publicar reportes SCA y SBOM'
            inputs:
              PathtoPublish: '$(Build.ArtifactStagingDirectory)/sca-reports'
              ArtifactName: 'SecurityReports-SCA'
              publishLocation: 'Container'
            condition: always()
```

## 2.2 Analizar la configuracion

### Tres pasos separados

El stage se divide en tres ejecuciones de Trivy:

| Paso | Comando | Salida |
|------|---------|--------|
| **1. Escaneo** | `trivy fs --format table --exit-code 1` | Tabla en logs + gate de severidad |
| **2. SARIF** | `trivy fs --format sarif` | Reporte SARIF para integraciones |
| **3. SBOM** | `trivy fs --format cyclonedx` | Inventario de componentes |

!!! tip "Por que tres ejecuciones"
    Trivy solo puede generar un formato de salida por ejecucion. Necesitamos:

    - **table** en los logs para visibilidad inmediata
    - **SARIF** para integracion con herramientas de seguridad
    - **CycloneDX** como SBOM para cumplimiento normativo

### Gate de severidad

```bash
--severity HIGH,CRITICAL \
--exit-code 1
```

| Parametro | Efecto |
|-----------|--------|
| `--severity HIGH,CRITICAL` | Solo reportar estas severidades |
| `--exit-code 1` | Salir con codigo 1 si hay hallazgos |

Esto significa que vulnerabilidades MEDIUM o LOW **no bloquearan** el pipeline, pero HIGH y CRITICAL si.

!!! warning "continueOnError: true"
    En la configuracion actual, el paso de escaneo tiene `continueOnError: true` para que los pasos de SARIF y SBOM puedan ejecutarse incluso si hay CVEs. Esto es una decision de diseño: queremos los reportes completos. En produccion, podrias quitar `continueOnError` para bloquear completamente.

### Artefactos publicados

El directorio `SecurityReports-SCA` contendra:

```
SecurityReports-SCA/
  trivy-sca-report.sarif    # Reporte SARIF
  sbom-cyclonedx.json        # SBOM en formato CycloneDX
```

## 2.3 Hacer push y verificar

```bash title="Terminal"
git add azure-pipelines.yml
git commit -m "lab05: implementar stage SCA con Trivy fs y SBOM"
git push origin main
```

Verifica en Azure DevOps:

1. Los stages **SecretsDetection**, **SAST** y **SCA** se ejecutan en secuencia
2. El stage SCA muestra la tabla de CVEs en los logs
3. Los artefactos `SecurityReports-SCA` estan disponibles con el SARIF y el SBOM
4. El SBOM CycloneDX lista todos los componentes de `requirements.txt`

## 2.4 Revisar los artefactos

Descarga los artefactos y revisa:

### SBOM CycloneDX

El SBOM se puede usar para:

- **Cumplimiento normativo** (NIST, EU CRA, Executive Order 14028)
- **Gestion de vulnerabilidades** futuras (cuando se descubre una nueva CVE, puedes buscar en tu SBOM)
- **Transparencia** con clientes sobre dependencias usadas

### SARIF

El SARIF se puede importar en:

- **Azure DevOps Advanced Security** (si esta habilitado)
- **GitHub Code Scanning**
- **DefectDojo**, **Snyk**, u otras plataformas de gestion de vulnerabilidades

## 2.5 Estado actual del pipeline

Despues de este lab, tu pipeline tiene tres stages implementados:

```text title="Estado del pipeline"
SecretsDetection (Gitleaks)     → Implementado - Lab 3
SAST (Semgrep)                  → Implementado - Lab 4
SCA (Trivy fs)                  → Implementado - Lab 5
Build                           → Placeholder  - Lab 6
ImageScan                       → Placeholder  - Lab 7
IaCScan                         → Placeholder  - Lab 9
DeployStaging                   → Placeholder  - Lab 10
DAST                            → Placeholder  - Lab 8
DeployProduction                → Placeholder  - Lab 10
Monitor                         → Placeholder  - Lab 11
```

!!! success "Paso Completado"
    El stage SCA esta implementado con Trivy fs. Detecta CVEs en dependencias, genera un reporte SARIF y un SBOM CycloneDX, y falla el pipeline si hay vulnerabilidades HIGH o CRITICAL.

## Resumen del Lab 5

| Concepto | Detalle |
|----------|---------|
| **Herramienta** | Trivy (modo `fs`) |
| **Stage** | `SCA` (tercero en el pipeline) |
| **Gate** | Falla en HIGH y CRITICAL |
| **Artefactos** | `trivy-sca-report.sarif`, `sbom-cyclonedx.json` |
| **SBOM** | CycloneDX 1.5 |
| **CVEs detectadas** | PyYAML, Werkzeug, requests, cryptography, Jinja2 |

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../step1/" class="md-button">Anterior: Paso 1</a>
  <a href="../../lab06-build/" class="md-button md-button--primary">Siguiente: Lab 6</a>
</div>
