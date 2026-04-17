---
tags:
  - lab
  - dast
  - owasp-zap
---

# Paso 2 -- Escaneo OWASP ZAP

!!! abstract "Objetivo"
    Agregar el escaneo DAST al pipeline usando OWASP ZAP en modo baseline y full scan contra la aplicacion en ejecucion. Publicar el reporte HTML como artefacto del pipeline.

## Contexto

OWASP ZAP (Zed Attack Proxy) ofrece dos modos de escaneo automatizado:

| Modo | Que hace | Duracion | Profundidad |
|------|----------|----------|-------------|
| **Baseline** | Spider + passive scan | 1-2 min | Detecta headers faltantes, cookies inseguras, info disclosure |
| **Full Scan** | Spider + passive + active scan | 5-20 min | Inyeccion SQL, XSS, CSRF, y mas ataques activos |

Ejecutaremos ambos para comparar los resultados.

## 2.1 ZAP Baseline Scan

El baseline scan es rapido y no invasivo. Solo navega la aplicacion y analiza las respuestas pasivamente:

```yaml title="vulnerable-app/.github/workflows/devsecops.yml -- ZAP Baseline (agregar dentro del job ZAPScan)"
          # ============================================================
          # OWASP ZAP: Baseline Scan
          # ============================================================
          - script: |
              echo "=== OWASP ZAP Baseline Scan ==="
              mkdir -p ${{ github.workspace }}/zap-reports

              # Ejecutar ZAP baseline scan via Docker
              # -t: URL objetivo
              # -r: Generar reporte HTML
              # -J: Generar reporte JSON
              # -I: No fallar por warnings (solo por FAILs)
              docker run --rm \
                --network host \
                -v ${{ github.workspace }}/zap-reports:/zap/wrk:rw \
                -t ghcr.io/zaproxy/zaproxy:stable \
                zap-baseline.py \
                  -t http://localhost:8080 \
                  -r zap-baseline-report.html \
                  -J zap-baseline-report.json \
                  -I

              echo ""
              echo "=== Baseline scan completado ==="
              ls -la ${{ github.workspace }}/zap-reports/
            name: 'ZAP Baseline Scan'
            continue-on-error: true
```

!!! tip "Flag --network host"
    Usamos `--network host` para que el contenedor de ZAP pueda alcanzar `localhost:8080` donde corre nuestra aplicacion. Sin este flag, ZAP no podria conectarse.

## 2.2 ZAP Full Scan

El full scan incluye ataques activos: inyeccion SQL, XSS, path traversal, etc.

```yaml title="vulnerable-app/.github/workflows/devsecops.yml -- ZAP Full Scan (agregar despues del baseline)"
          # ============================================================
          # OWASP ZAP: Full Scan
          # ============================================================
          - script: |
              echo "=== OWASP ZAP Full Scan ==="

              # Full scan con ataques activos
              # -t: URL objetivo
              # -r: Reporte HTML
              # -J: Reporte JSON
              # -m: Minutos maximos de escaneo (10 min)
              # -I: No fallar por warnings
              docker run --rm \
                --network host \
                -v ${{ github.workspace }}/zap-reports:/zap/wrk:rw \
                -t ghcr.io/zaproxy/zaproxy:stable \
                zap-full-scan.py \
                  -t http://localhost:8080 \
                  -r zap-full-report.html \
                  -J zap-full-report.json \
                  -m 10 \
                  -I

              echo ""
              echo "=== Full scan completado ==="
              ls -la ${{ github.workspace }}/zap-reports/
            name: 'ZAP Full Scan'
            continue-on-error: true
```

## 2.3 Publicar reportes como artefactos

```yaml title="vulnerable-app/.github/workflows/devsecops.yml -- Publicar reportes ZAP"
          # --- Publicar reportes ZAP ---
          - uses: actions/upload-artifact@v4
            name: 'Publicar reportes ZAP'
            inputs:
              PathtoPublish: '${{ github.workspace }}/zap-reports'
              ArtifactName: 'zap-reports'
              publishLocation: 'Container'
            if: always()
```

## 2.4 Stage DAST completo

Para referencia, asi queda el stage `DAST` completo con todos los pasos:

```yaml title="vulnerable-app/.github/workflows/devsecops.yml -- Stage DAST completo"
  - stage: DAST
    name: 'DAST — OWASP ZAP'
    dependsOn: ImageScan
    jobs:
      - job: ZAPScan
        name: 'OWASP ZAP Scan'
        timeoutInMinutes: 30
        steps:
          - checkout: self

          # --- Levantar la aplicacion ---
          - script: |
              echo "=== Levantando aplicacion para DAST ==="
              cd vulnerable-app/
              docker compose up -d --build

              MAX_RETRIES=12
              RETRY_COUNT=0
              until curl -sf http://localhost:8080/health > /dev/null 2>&1; do
                RETRY_COUNT=$((RETRY_COUNT + 1))
                if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
                  echo "ERROR: La aplicacion no respondio"
                  docker compose logs
                  exit 1
                fi
                echo "  Intento ${RETRY_COUNT}/${MAX_RETRIES} - esperando 5s..."
                sleep 5
              done
              echo "Aplicacion lista en http://localhost:8080"
            name: 'Docker Compose Up + Health Check'

          # --- Verificar endpoints ---
          - script: |
              echo "=== Verificando endpoints ==="
              curl -s http://localhost:8080/ | python3 -m json.tool
              curl -s http://localhost:8080/health | python3 -m json.tool
              curl -s http://localhost:8080/api/users | python3 -m json.tool
              curl -s "http://localhost:8080/search?q=test" | head -10
            name: 'Verificar endpoints'

          # --- ZAP Baseline ---
          - script: |
              mkdir -p ${{ github.workspace }}/zap-reports
              docker run --rm \
                --network host \
                -v ${{ github.workspace }}/zap-reports:/zap/wrk:rw \
                -t ghcr.io/zaproxy/zaproxy:stable \
                zap-baseline.py \
                  -t http://localhost:8080 \
                  -r zap-baseline-report.html \
                  -J zap-baseline-report.json \
                  -I
            name: 'ZAP Baseline Scan'
            continue-on-error: true

          # --- ZAP Full Scan ---
          - script: |
              docker run --rm \
                --network host \
                -v ${{ github.workspace }}/zap-reports:/zap/wrk:rw \
                -t ghcr.io/zaproxy/zaproxy:stable \
                zap-full-scan.py \
                  -t http://localhost:8080 \
                  -r zap-full-report.html \
                  -J zap-full-report.json \
                  -m 10 \
                  -I
            name: 'ZAP Full Scan'
            continue-on-error: true

          # --- Gate: Fallar si hay alertas High ---
          - script: |
              echo "=== Evaluando resultados ZAP ==="
              REPORT="${{ github.workspace }}/zap-reports/zap-full-report.json"

              if [ ! -f "$REPORT" ]; then
                echo "WARN: Reporte JSON no encontrado"
                exit 0
              fi

              # Contar alertas High y Critical
              HIGH_COUNT=$(python3 -c "
              import json
              with open('$REPORT') as f:
                  data = json.load(f)
              alerts = data.get('site', [{}])[0].get('alerts', [])
              high = [a for a in alerts if a.get('riskcode', '0') in ('3', '2')]
              print(len(high))
              " 2>/dev/null || echo "0")

              echo "Alertas High/Critical encontradas: $HIGH_COUNT"

              if [ "$HIGH_COUNT" -gt 0 ]; then
                echo "::warning::ZAP encontro $HIGH_COUNT alertas High/Critical"
                echo "Revisa el reporte HTML para detalles"
                # Descomentar para bloquear el pipeline:
                # exit 1
              else
                echo "Sin alertas High/Critical"
              fi
            name: 'ZAP Gate (High alerts)'
            continue-on-error: true

          # --- Publicar reportes ---
          - uses: actions/upload-artifact@v4
            name: 'Publicar reportes ZAP'
            inputs:
              PathtoPublish: '${{ github.workspace }}/zap-reports'
              ArtifactName: 'zap-reports'
              publishLocation: 'Container'
            if: always()

          # --- Limpiar Docker Compose ---
          - script: |
              cd vulnerable-app/
              docker compose down -v
              echo "Aplicacion detenida"
            name: 'Docker Compose Down'
            if: always()
```

## 2.5 Que vulnerabilidades esperamos

Dado que nuestra aplicacion tiene vulnerabilidades intencionales, ZAP deberia detectar:

| Vulnerabilidad | Riesgo ZAP | Endpoint | CWE |
|----------------|------------|----------|-----|
| Reflected XSS | High | `/search?q=<script>` | CWE-79 |
| SQL Injection | High | `/login` | CWE-89 |
| Missing Anti-CSRF Tokens | Medium | `/login`, `/register` | CWE-352 |
| X-Frame-Options Missing | Medium | Todos | CWE-1021 |
| Content-Security-Policy Missing | Medium | Todos | CWE-693 |
| X-Content-Type-Options Missing | Low | Todos | CWE-693 |
| Server Leaks Info | Low | Todos | CWE-200 |
| Application Error Disclosure | Medium | `/login` (con injection) | CWE-209 |

!!! warning "Escaneo activo = ataques reales"
    El full scan de ZAP envia payloads de ataque reales (SQL injection, XSS, etc.). Solo ejecutalo contra aplicaciones en entornos de prueba, **nunca** contra produccion sin autorizacion explicita.

## 2.6 Verificar en GitHub Actions

1. Haz commit y push del pipeline actualizado
2. Ve a **Pipelines** > tu pipeline > ultimo run
3. El stage **DAST** deberia mostrar:
    - Docker Compose levantando la app
    - Health check exitoso
    - ZAP baseline scan
    - ZAP full scan
4. Descarga el artefacto `zap-reports` y abre `zap-full-report.html` en un navegador

!!! success "Paso Completado"
    Has ejecutado un escaneo DAST completo con OWASP ZAP contra la aplicacion vulnerable. Los reportes HTML y JSON estan disponibles como artefactos del pipeline. En el siguiente paso interpretaremos los resultados y ajustaremos la configuracion.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="step1.md" class="md-button">Anterior: Desplegar en Agente</a>
  <a href="step3.md" class="md-button md-button--primary">Siguiente: Analisis y Ajuste</a>
</div>
