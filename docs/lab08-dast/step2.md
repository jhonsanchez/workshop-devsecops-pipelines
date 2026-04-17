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

```yaml title=".github/workflows/devsecops.yml -- ZAP Baseline (agregar dentro del job dast)"
      # ============================================================
      # OWASP ZAP: Baseline Scan
      # ============================================================
      - name: ZAP Baseline Scan
        continue-on-error: true
        run: |
          echo "=== OWASP ZAP Baseline Scan ==="
          mkdir -p zap-reports

          # Ejecutar ZAP baseline scan via Docker
          # -t: URL objetivo
          # -r: Generar reporte HTML
          # -J: Generar reporte JSON
          # -I: No fallar por warnings (solo por FAILs)
          docker run --rm \
            --network host \
            -v ${{ github.workspace }}/zap-reports:/zap/wrk \
            ghcr.io/zaproxy/zaproxy:stable \
            zap-baseline.py \
              -t http://localhost:8080 \
              -r zap-baseline-report.html \
              -J zap-baseline-report.json \
              -I

          echo ""
          echo "=== Baseline scan completado ==="
          ls -la zap-reports/
```

!!! tip "Flag --network host"
    Usamos `--network host` para que el contenedor de ZAP pueda alcanzar `localhost:8080` donde corre nuestra aplicacion. Sin este flag, ZAP no podria conectarse.

## 2.2 ZAP Full Scan

El full scan incluye ataques activos: inyeccion SQL, XSS, path traversal, etc.

```yaml title=".github/workflows/devsecops.yml -- ZAP Full Scan (agregar despues del baseline)"
      # ============================================================
      # OWASP ZAP: Full Scan
      # ============================================================
      - name: OWASP ZAP — Full Scan
        continue-on-error: true
        run: |
          echo "=== OWASP ZAP Full Scan ==="
          mkdir -p zap-reports

          # Full scan con ataques activos
          # -t: URL objetivo
          # -r: Reporte HTML
          # -J: Reporte JSON
          # -m: Minutos maximos de escaneo (10 min)
          # -I: No fallar por warnings
          docker run --rm \
            --network host \
            -v ${{ github.workspace }}/zap-reports:/zap/wrk \
            ghcr.io/zaproxy/zaproxy:stable \
            zap-full-scan.py \
              -t http://localhost:8080 \
              -r zap-full-report.html \
              -J zap-full-report.json \
              -m 10 \
              -I

          echo ""
          echo "=== Full scan completado ==="
          ls -la zap-reports/
```

## 2.3 Publicar reportes como artefactos

```yaml title=".github/workflows/devsecops.yml -- Publicar reportes ZAP"
      # --- Publicar reportes ZAP ---
      - name: Publicar reporte ZAP
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: zap-report
          path: zap-reports/
          retention-days: 30
```

## 2.4 Stage DAST completo

Para referencia, asi queda el stage `DAST` completo con todos los pasos:

```yaml title=".github/workflows/devsecops.yml -- Job dast completo"
  dast:
    name: '8. Análisis Dinámico (DAST)'
    runs-on: ubuntu-latest
    needs: deploy-staging
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      # --- Levantar la aplicacion ---
      - name: Levantar aplicación
        run: |
          cd vulnerable-app && docker compose up -d --build
          sleep 10
          curl -sf http://localhost:8080/health || (docker compose -f vulnerable-app/docker-compose.yml logs && exit 1)

      # --- ZAP Full Scan ---
      - name: OWASP ZAP — Full Scan
        run: |
          mkdir -p zap-reports
          docker run --rm --network host \
            -v ${{ github.workspace }}/zap-reports:/zap/wrk \
            ghcr.io/zaproxy/zaproxy:stable \
            zap-full-scan.py \
            -t http://localhost:8080 \
            -r zap-report.html \
            -J zap-report.json \
            -I || true

      # --- Publicar reportes ---
      - name: Publicar reporte ZAP
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: zap-report
          path: zap-reports/
          retention-days: 30

      # --- Evaluar resultados ---
      - name: Evaluar resultados DAST
        if: always()
        run: |
          if [ -f "zap-reports/zap-report.json" ]; then
            HIGH_COUNT=$(python3 -c "
          import json
          data = json.load(open('zap-reports/zap-report.json'))
          alerts = data.get('site', [{}])[0].get('alerts', []) if data.get('site') else []
          high = sum(1 for a in alerts if int(a.get('riskcode', 0)) >= 3)
          print(high)
          " 2>/dev/null || echo "0")
            echo "Alertas High/Critical: $HIGH_COUNT"
            echo "### DAST Results :shield:" >> $GITHUB_STEP_SUMMARY
            echo "- **High/Critical alerts:** $HIGH_COUNT" >> $GITHUB_STEP_SUMMARY
          fi

      # --- Limpiar Docker Compose ---
      - name: Detener aplicación
        if: always()
        run: cd vulnerable-app && docker compose down
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
