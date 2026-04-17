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
    Implementar el job `sca` en `.github/workflows/devsecops.yml` con Trivy fs, configurar un gate de severidad (fallar en HIGH/CRITICAL), generar un SBOM CycloneDX y publicarlo como artefacto del build.

## 2.1 Reemplazar el placeholder de sca

Abre `.github/workflows/devsecops.yml` y reemplaza el job `sca` completo:

```yaml title=".github/workflows/devsecops.yml — job sca"
  # ──────────────────────────────────────────────
  # Job 3: SCA - Composicion de Software (Trivy)
  # ──────────────────────────────────────────────
  sca:
    name: 'SCA - Dependencias'
    needs: sast
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        name: 'Checkout del repositorio'

      # --- Paso 1: Escaneo de vulnerabilidades ---
      - run: |
          echo "=== Trivy FS — Analisis de Composicion de Software ==="
          echo "Directorio: ${{ env.APP_DIRECTORY }}"
          echo ""

          mkdir -p sca-reports

          # Escaneo de CVEs en dependencias
          docker run --rm \
            -v "${{ github.workspace }}:/src" \
            -v "${{ github.workspace }}/sca-reports:/reports" \
            aquasec/trivy:latest \
            fs /src/${{ env.APP_DIRECTORY }}/ \
              --severity HIGH,CRITICAL \
              --exit-code 1 \
              --format table

          TRIVY_EXIT=$?

          echo ""
          echo "Trivy exit code: $TRIVY_EXIT"

          if [ $TRIVY_EXIT -ne 0 ]; then
            echo "::warning::Trivy detecto vulnerabilidades HIGH o CRITICAL en las dependencias"
          else
            echo "No se detectaron vulnerabilidades HIGH/CRITICAL."
          fi

          exit $TRIVY_EXIT
        name: 'Escanear CVEs en dependencias'
        continue-on-error: true

      # --- Paso 2: Generar reporte SARIF ---
      - if: always()
        run: |
          docker run --rm \
            -v "${{ github.workspace }}:/src" \
            -v "${{ github.workspace }}/sca-reports:/reports" \
            aquasec/trivy:latest \
            fs /src/${{ env.APP_DIRECTORY }}/ \
              --format sarif \
              --output /reports/trivy-sca-report.sarif

          echo "Reporte SARIF generado."
        name: 'Generar reporte SARIF'

      # --- Paso 3: Generar SBOM CycloneDX ---
      - if: always()
        run: |
          docker run --rm \
            -v "${{ github.workspace }}:/src" \
            -v "${{ github.workspace }}/sca-reports:/reports" \
            aquasec/trivy:latest \
            fs /src/${{ env.APP_DIRECTORY }}/ \
              --format cyclonedx \
              --output /reports/sbom-cyclonedx.json

          echo "SBOM CycloneDX generado."

          # Mostrar resumen del SBOM
          python3 -c "
import json
with open('sca-reports/sbom-cyclonedx.json') as f:
    sbom = json.load(f)
    components = sbom.get('components', [])
    print(f'')
    print(f'=== SBOM Resumen ===')
    print(f'Formato: {sbom.get(\"bomFormat\")}')
    print(f'Componentes: {len(components)}')
    for c in components:
        print(f'  - {c.get(\"name\")}=={c.get(\"version\", \"?\")}')
"
        name: 'Generar SBOM CycloneDX'

      # --- Paso 4: Publicar artefactos ---
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: SecurityReports-SCA
          path: sca-reports/
        name: 'Publicar reportes SCA y SBOM'
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

!!! warning "continue-on-error: true"
    En la configuracion actual, el paso de escaneo tiene `continue-on-error: true` para que los pasos de SARIF y SBOM puedan ejecutarse incluso si hay CVEs. Esto es una decision de diseño: queremos los reportes completos. En produccion, podrias quitar `continue-on-error` para bloquear completamente.

### Artefactos publicados

El directorio `SecurityReports-SCA` contendra:

```
SecurityReports-SCA/
  trivy-sca-report.sarif    # Reporte SARIF
  sbom-cyclonedx.json        # SBOM en formato CycloneDX
```

## 2.3 Hacer push y verificar

```bash title="Terminal"
git add .github/workflows/devsecops.yml
git commit -m "lab05: implementar job SCA con Trivy fs y SBOM"
git push origin main
```

Verifica en GitHub Actions:

1. Los jobs **secrets-detection**, **sast** y **sca** se ejecutan en secuencia
2. El job SCA muestra la tabla de CVEs en los logs
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

- **GitHub Advanced Security** (si esta habilitado)
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
    El job SCA esta implementado con Trivy fs. Detecta CVEs en dependencias, genera un reporte SARIF y un SBOM CycloneDX, y falla el workflow si hay vulnerabilidades HIGH o CRITICAL.

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
