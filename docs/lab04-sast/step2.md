---
tags:
  - lab
  - sast
  - semgrep
  - pipeline
---

# Paso 2 -- Añadir Job SAST

!!! abstract "Objetivo"
    Implementar el job `sast` en `.github/workflows/devsecops.yml` usando Semgrep en Docker con los rulesets `p/owasp-top-ten` y `p/secrets`, publicar el reporte SARIF como artefacto del workflow.

## 2.1 Reemplazar el placeholder de sast

Abre `.github/workflows/devsecops.yml` y reemplaza el job `sast` completo:

```yaml title=".github/workflows/devsecops.yml — job sast"
  # ──────────────────────────────────────────────
  # Job 2: SAST - Analisis Estatico (Semgrep)
  # ──────────────────────────────────────────────
  sast:
    name: 'SAST - Analisis Estatico'
    needs: secrets-detection
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        name: 'Checkout del repositorio'

      - run: |
          echo "=== Semgrep — Analisis Estatico de Seguridad ==="
          echo "Directorio: ${{ env.APP_DIRECTORY }}"
          echo "Rulesets: p/owasp-top-ten, p/secrets"
          echo ""

          docker run --rm \
            -v "${{ github.workspace }}:/src" \
            -e SEMGREP_RULES="p/owasp-top-ten p/secrets" \
            semgrep/semgrep:latest \
            semgrep scan \
              --config p/owasp-top-ten \
              --config p/secrets \
              --sarif \
              --output /src/semgrep-report.sarif \
              /src/${{ env.APP_DIRECTORY }}/

          SEMGREP_EXIT=$?

          echo ""
          echo "Semgrep exit code: $SEMGREP_EXIT"

          # Mostrar resumen de hallazgos
          if [ -f "${{ github.workspace }}/semgrep-report.sarif" ]; then
            echo ""
            echo "--- Resumen de hallazgos ---"
            python3 -c "
import json, sys
with open('${{ github.workspace }}/semgrep-report.sarif') as f:
    data = json.load(f)
    results = data.get('runs', [{}])[0].get('results', [])
    errors = sum(1 for r in results if r.get('level') == 'error')
    warnings = sum(1 for r in results if r.get('level') == 'warning')
    print(f'Total: {len(results)} hallazgos ({errors} errores, {warnings} warnings)')
    for r in results:
        loc = r['locations'][0]['physicalLocation']
        uri = loc['artifactLocation']['uri']
        line = loc['region']['startLine']
        print(f'  [{r[\"level\"]:>7}] {r[\"ruleId\"]} — {uri}:{line}')
"
          fi

          exit $SEMGREP_EXIT
        name: 'Ejecutar Semgrep'

      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: SecurityReports-Semgrep
          path: semgrep-report.sarif
        name: 'Publicar reporte SARIF'
```

## 2.2 Analizar la configuracion

### Rulesets utilizados

| Ruleset | Que detecta | Reglas aprox. |
|---------|-------------|---------------|
| `p/owasp-top-ten` | Las 10 categorias de OWASP Top 10 2021 | ~300 reglas |
| `p/secrets` | Credenciales hardcodeadas, tokens, API keys | ~100 reglas |

!!! tip "Otros rulesets disponibles"
    Semgrep tiene cientos de rulesets. Algunos utiles para Python:

    - `p/python` -- Reglas generales de seguridad para Python
    - `p/flask` -- Reglas especificas para Flask
    - `p/django` -- Reglas para Django
    - `p/bandit` -- Equivalente a las reglas de Bandit
    - `p/default` -- Ruleset por defecto de Semgrep (curado)

### Variables de entorno

La imagen Docker de Semgrep acepta varias variables de entorno:

| Variable | Descripcion |
|----------|-------------|
| `SEMGREP_RULES` | Rulesets a utilizar (alternativa a `--config`) |
| `SEMGREP_APP_TOKEN` | Token para Semgrep App (telemetria y resultados en la nube) |
| `SEMGREP_TIMEOUT` | Timeout por archivo en segundos (default: 30) |

### Comportamiento por defecto de Semgrep

Semgrep sale con codigo **1** si encuentra hallazgos de severidad ERROR. Este es el comportamiento que queremos: que el workflow falle si hay vulnerabilidades criticas.

| Exit code | Significado |
|-----------|-------------|
| 0 | Sin hallazgos (o solo INFO/WARNING segun config) |
| 1 | Hallazgos encontrados |
| 2 | Error de ejecucion (config invalida, etc.) |

## 2.3 Configurar con Semgrep App Token (opcional)

Si tienes una cuenta en [Semgrep App](https://semgrep.dev), puedes enviar resultados a la plataforma web para tener un dashboard centralizado:

```yaml title="Con Semgrep App Token"
      - run: |
          docker run --rm \
            -v "${{ github.workspace }}:/src" \
            -e SEMGREP_APP_TOKEN=${{ secrets.SEMGREP_APP_TOKEN }} \
            semgrep/semgrep:latest \
            semgrep ci \
              --sarif \
              --output /src/semgrep-report.sarif \
              /src/${{ env.APP_DIRECTORY }}/
        name: 'Ejecutar Semgrep CI'
```

!!! info "semgrep ci vs semgrep scan"
    `semgrep ci` es el comando optimizado para CI/CD: detecta automaticamente la rama base, hace diff-aware scanning (solo escanea archivos cambiados), y reporta a Semgrep App si el token esta configurado.

## 2.4 Hacer push y verificar

```bash title="Terminal"
git add .github/workflows/devsecops.yml
git commit -m "lab04: implementar job SAST con Semgrep"
git push origin main
```

Verifica en GitHub Actions:

1. El job **secrets-detection** se ejecuta primero
2. El job **sast** se ejecuta despues
3. Semgrep detecta las vulnerabilidades en `vulnerable-app/`
4. El artefacto `SecurityReports-Semgrep` esta disponible con el reporte SARIF
5. Los logs muestran el resumen de hallazgos con sus severidades

!!! warning "El workflow puede fallar"
    Si Semgrep encuentra hallazgos de severidad ERROR (como el SQL Injection), el job fallara. Esto es el comportamiento esperado. Puedes agregar `|| true` temporalmente al comando para continuar con los demas labs.

## 2.5 Descargar y revisar el reporte SARIF

1. En el detalle del run, ve a **Artifacts**
2. Descarga `SecurityReports-Semgrep`
3. El archivo `semgrep-report.sarif` contiene todos los hallazgos en formato estandar

El reporte incluye para cada hallazgo:

- **ruleId** -- Identificador de la regla
- **level** -- error, warning o note
- **message** -- Descripcion de la vulnerabilidad
- **locations** -- Archivo y linea exacta
- **fingerprints** -- Para tracking entre ejecuciones

!!! success "Paso Completado"
    El stage SAST esta implementado con Semgrep usando los rulesets `p/owasp-top-ten` y `p/secrets`. Los resultados se publican como artefacto SARIF.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../step1/" class="md-button">Anterior: Paso 1</a>
  <a href="../step3/" class="md-button md-button--primary">Paso 3: Reglas Personalizadas</a>
</div>
