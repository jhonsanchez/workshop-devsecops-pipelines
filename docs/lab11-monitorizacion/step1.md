---
tags:
  - lab
  - monitoring
  - health-check
  - github-actions
---

# Paso 1 -- Health Checks y Alertas

!!! abstract "Objetivo"
    Agregar el job monitor al pipeline con health checks post-despliegue, smoke tests que validen funcionalidad basica, y verificacion de cabeceras de seguridad. Configurar anotaciones y Job Summary en GitHub Actions para reportar resultados.

## 1.1 Agregar el stage Monitor al pipeline

```yaml title="vulnerable-app/.github/workflows/devsecops.yml -- Job monitor"
  # ============================================================
  # Lab 11: Monitorizacion Post-Despliegue
  # ============================================================

  # ── Job 10: Verificacion Post-Despliegue ──────────────────────
  monitor:
    name: '10. Verificacion Post-Despliegue'
    runs-on: ubuntu-latest
    needs: deploy-production
    steps:
      - uses: actions/checkout@v4

      # --- Levantar aplicacion (simulacion produccion) ---
      - name: Levantar aplicacion (simulacion produccion)
        run: |
          cd vulnerable-app && docker compose up -d --build
          sleep 10

      # --- Health Checks y Smoke Tests ---
      - name: Health Checks y Smoke Tests
        run: |
          echo "=== Health Check ==="
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
          echo "Health endpoint: $STATUS"
          [ "$STATUS" != "200" ] && echo "::error::Health check fallo" && exit 1

          echo "=== Smoke Tests ==="
          for endpoint in / /health "/search?q=test"; do
            CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080$endpoint")
            echo "  $endpoint → $CODE"
            [ "$CODE" -ge "500" ] && echo "::error::Endpoint $endpoint devolvio $CODE" && exit 1
          done

          echo "=== Verificar cabeceras de seguridad ==="
          HEADERS=$(curl -sI http://localhost:8080/)
          echo "$HEADERS" | grep -qi "x-content-type-options" && echo "  X-Content-Type-Options: OK" || echo "::warning::Falta X-Content-Type-Options"
          echo "$HEADERS" | grep -qi "x-frame-options" && echo "  X-Frame-Options: OK" || echo "::warning::Falta X-Frame-Options"

          echo "=== Despliegue verificado ==="

      # --- Resumen del Pipeline ---
      - name: Resumen del Pipeline
        run: |
          echo "### Pipeline DevSecOps Completado" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Stage | Herramienta | Estado |" >> $GITHUB_STEP_SUMMARY
          echo "|---|---|---|" >> $GITHUB_STEP_SUMMARY
          echo "| Secretos | Gitleaks | Completado |" >> $GITHUB_STEP_SUMMARY
          echo "| SAST | Semgrep | Completado |" >> $GITHUB_STEP_SUMMARY
          echo "| SCA | Trivy FS | Completado |" >> $GITHUB_STEP_SUMMARY
          echo "| Build | Docker + GHCR | Completado |" >> $GITHUB_STEP_SUMMARY
          echo "| Image Scan | Trivy + Cosign | Completado |" >> $GITHUB_STEP_SUMMARY
          echo "| IaC | Checkov | Completado |" >> $GITHUB_STEP_SUMMARY
          echo "| Staging | Docker Compose | Completado |" >> $GITHUB_STEP_SUMMARY
          echo "| DAST | OWASP ZAP | Completado |" >> $GITHUB_STEP_SUMMARY
          echo "| Produccion | Cosign verify + Deploy | Completado |" >> $GITHUB_STEP_SUMMARY
          echo "| Monitor | Health + Smoke | Completado |" >> $GITHUB_STEP_SUMMARY

      # --- Detener aplicacion ---
      - name: Detener aplicacion
        if: always()
        run: cd vulnerable-app && docker compose down
```

## 1.2 Alertas y monitorizacion con GitHub Actions

GitHub Actions ofrece varias formas de implementar monitorizacion y alertas dentro del pipeline:

### Anotaciones en el workflow

El job `monitor` usa anotaciones de GitHub Actions para reportar problemas:

| Anotacion | Sintaxis | Uso |
|-----------|----------|-----|
| Error | `echo "::error::mensaje"` | Health check fallo, endpoint devolvio 5xx |
| Warning | `echo "::warning::mensaje"` | Falta cabecera de seguridad, rendimiento degradado |
| Notice | `echo "::notice::mensaje"` | Informacion relevante del despliegue |

### Job Summary

El pipeline genera un resumen automatico en `$GITHUB_STEP_SUMMARY` con una tabla de todos los stages y su resultado. Este resumen es visible en la pagina del workflow run.

### Notificaciones de GitHub

Configura notificaciones para recibir alertas cuando el workflow falle:

1. Ve a **Settings** > **Notifications** en tu perfil de GitHub
2. Activa notificaciones para **Actions** en el repositorio
3. Configura email o notificaciones web

### Monitorizacion avanzada (opcional)

Para entornos de produccion reales, puedes agregar pasos adicionales al job `monitor`:

```yaml title="Ejemplo: Alerta via webhook cuando falla el health check"
      - name: Notificar fallo al equipo de seguridad
        if: failure()
        run: |
          curl -X POST "${{ secrets.SLACK_WEBHOOK_URL }}" \
            -H "Content-Type: application/json" \
            -d '{
              "text": "ALERTA: Health check fallo en produccion. Run: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
            }'
```

## 1.3 Resumen de verificaciones del job monitor

| Verificacion | Metodo | Criterio de fallo | Accion |
|-------------|--------|-------------------|--------|
| Health Check | `curl /health` | HTTP != 200 | `::error::` + exit 1 |
| Smoke Tests | `curl` a multiples endpoints | HTTP >= 500 | `::error::` + exit 1 |
| Cabeceras de seguridad | `curl -I` + grep | Cabecera ausente | `::warning::` |
| Resumen | `$GITHUB_STEP_SUMMARY` | N/A | Tabla de resultados |

!!! success "Paso Completado"
    Has agregado el job monitor al pipeline con health checks, smoke tests y verificacion de cabeceras de seguridad. Los resultados se reportan mediante anotaciones de GitHub Actions y el Job Summary. En el siguiente paso construiremos un dashboard de seguridad.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="index.md" class="md-button">Anterior: Introduccion</a>
  <a href="step2.md" class="md-button md-button--primary">Siguiente: Dashboard de Seguridad</a>
</div>
