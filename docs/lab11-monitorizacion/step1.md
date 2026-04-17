---
tags:
  - lab
  - monitoring
  - health-check
  - azure-monitor
---

# Paso 1 -- Health Checks y Alertas

!!! abstract "Objetivo"
    Agregar el stage Monitor al pipeline con health checks post-despliegue, smoke tests que validen funcionalidad basica, y configurar alertas en Azure Monitor para detectar eventos de seguridad como spikes de HTTP 500 y tasas altas de autenticacion fallida.

## 1.1 Agregar el stage Monitor al pipeline

```yaml title="vulnerable-app/azure-pipelines.yml -- Stage Monitor"
  # ============================================================
  # Lab 11: Monitorizacion Post-Despliegue
  # ============================================================
  - stage: Monitor
    displayName: 'Monitor — Post-Deploy'
    dependsOn: DeployProduction
    variables:
      prodUrl: 'https://workshop-app-production.azurewebsites.net'
    jobs:
      - job: HealthChecks
        displayName: 'Health Checks + Smoke Tests'
        steps:
          # --- Health Check basico ---
          - script: |
              echo "=== Health Check: Production ==="
              echo "URL: $(prodUrl)"
              echo ""

              # Health check con reintentos
              MAX_RETRIES=6
              RETRY_COUNT=0
              HTTP_CODE=0

              until [ "$HTTP_CODE" = "200" ]; do
                RETRY_COUNT=$((RETRY_COUNT + 1))
                if [ $RETRY_COUNT -gt $MAX_RETRIES ]; then
                  echo "FAIL: Health check fallo despues de $MAX_RETRIES intentos"
                  echo "Ultimo HTTP code: $HTTP_CODE"
                  exit 1
                fi

                HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$(prodUrl)/health")
                echo "  Intento ${RETRY_COUNT}: HTTP $HTTP_CODE"

                if [ "$HTTP_CODE" != "200" ]; then
                  sleep 10
                fi
              done

              echo ""
              echo "Health check: PASS (HTTP 200)"
              curl -s "$(prodUrl)/health" | python3 -m json.tool
            displayName: 'Health Check'

          # --- Smoke Tests ---
          - script: |
              echo "=== Smoke Tests: Production ==="
              echo ""
              FAILURES=0

              # Test 1: Endpoint raiz responde
              echo "--- Test 1: GET / ---"
              RESPONSE=$(curl -s -w "\n%{http_code}" "$(prodUrl)/")
              HTTP_CODE=$(echo "$RESPONSE" | tail -1)
              BODY=$(echo "$RESPONSE" | head -n -1)

              if [ "$HTTP_CODE" = "200" ]; then
                echo "  PASS: HTTP $HTTP_CODE"
              else
                echo "  FAIL: HTTP $HTTP_CODE (esperado 200)"
                FAILURES=$((FAILURES + 1))
              fi

              # Test 2: API users responde (aunque sea vulnerable)
              echo "--- Test 2: GET /api/users ---"
              HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$(prodUrl)/api/users")
              if [ "$HTTP_CODE" = "200" ]; then
                echo "  PASS: HTTP $HTTP_CODE"
              else
                echo "  FAIL: HTTP $HTTP_CODE (esperado 200)"
                FAILURES=$((FAILURES + 1))
              fi

              # Test 3: Search funciona
              echo "--- Test 3: GET /search?q=test ---"
              HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$(prodUrl)/search?q=test")
              if [ "$HTTP_CODE" = "200" ]; then
                echo "  PASS: HTTP $HTTP_CODE"
              else
                echo "  FAIL: HTTP $HTTP_CODE (esperado 200)"
                FAILURES=$((FAILURES + 1))
              fi

              # Test 4: Login endpoint disponible
              echo "--- Test 4: POST /login ---"
              HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
                -X POST "$(prodUrl)/login" \
                -d "username=test&password=test")
              if [ "$HTTP_CODE" = "401" ]; then
                echo "  PASS: HTTP $HTTP_CODE (credenciales invalidas = esperado)"
              else
                echo "  WARN: HTTP $HTTP_CODE (esperado 401)"
              fi

              # Test 5: Endpoint inexistente devuelve 404
              echo "--- Test 5: GET /no-existe ---"
              HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$(prodUrl)/no-existe")
              if [ "$HTTP_CODE" = "404" ]; then
                echo "  PASS: HTTP $HTTP_CODE"
              else
                echo "  WARN: HTTP $HTTP_CODE (esperado 404)"
              fi

              echo ""
              echo "=== Resultado: $FAILURES fallos ==="

              if [ $FAILURES -gt 0 ]; then
                echo "##vso[task.logissue type=warning]$FAILURES smoke tests fallaron"
                exit 1
              fi
            displayName: 'Smoke Tests'

          # --- Test de rendimiento basico ---
          - script: |
              echo "=== Test de rendimiento basico ==="
              echo ""

              # Medir tiempo de respuesta promedio (10 requests)
              TOTAL_TIME=0
              NUM_REQUESTS=10

              for i in $(seq 1 $NUM_REQUESTS); do
                TIME=$(curl -s -o /dev/null -w "%{time_total}" "$(prodUrl)/health")
                TOTAL_TIME=$(echo "$TOTAL_TIME + $TIME" | bc)
                echo "  Request $i: ${TIME}s"
              done

              AVG_TIME=$(echo "scale=3; $TOTAL_TIME / $NUM_REQUESTS" | bc)
              echo ""
              echo "Tiempo promedio: ${AVG_TIME}s"

              # Alerta si el promedio supera 2 segundos
              THRESHOLD="2.000"
              if [ $(echo "$AVG_TIME > $THRESHOLD" | bc -l) -eq 1 ]; then
                echo "##vso[task.logissue type=warning]Tiempo de respuesta promedio ($AVG_TIME s) supera el umbral ($THRESHOLD s)"
              else
                echo "Rendimiento OK (< $THRESHOLD s)"
              fi
            displayName: 'Test de rendimiento basico'
            continueOnError: true

          # --- Resumen del pipeline ---
          - script: |
              echo "============================================="
              echo "  PIPELINE DEVSECOPS COMPLETADO"
              echo "============================================="
              echo ""
              echo "Stages ejecutados:"
              echo "  1. Checkout"
              echo "  2. SecretsDetection (Gitleaks)"
              echo "  3. SAST (Semgrep)"
              echo "  4. SCA (Trivy fs + SBOM)"
              echo "  5. Build (Docker + ACR)"
              echo "  6. ImageScan (Trivy image + Cosign sign)"
              echo "  7. DAST (OWASP ZAP)"
              echo "  8. IaCScan (Checkov + Conftest)"
              echo "  9. DeployStaging (Terraform + aprobacion)"
              echo " 10. DeployProduction (Cosign verify + Terraform + aprobacion)"
              echo " 11. Monitor (Health checks + Smoke tests)"
              echo ""
              echo "URL de produccion: $(prodUrl)"
              echo "Build ID: $(Build.BuildId)"
              echo "Commit: $(Build.SourceVersion)"
              echo "============================================="
            displayName: 'Resumen del Pipeline'
```

## 1.2 Configurar Azure Monitor

Azure Monitor permite crear alertas automaticas basadas en metricas y logs. Configura estas alertas para la aplicacion desplegada:

### Alerta: Spike de HTTP 500

1. En Azure Portal, ve a tu **App Service** > **Monitoring** > **Alerts**
2. Click en **+ New alert rule**
3. Configura:

| Campo | Valor |
|-------|-------|
| Signal | `Http Server Errors` (metric) |
| Threshold | Dynamic o Static > 5 en 5 minutos |
| Action Group | Crear uno con email del equipo de seguridad |
| Alert rule name | `HTTP 500 Spike - Production` |
| Severity | Sev 2 (Warning) |

```json title="Azure Monitor Alert Rule (ARM template - referencia)"
{
  "type": "Microsoft.Insights/metricAlerts",
  "name": "http-500-spike-production",
  "properties": {
    "description": "Alerta cuando HTTP 500 supera umbral",
    "severity": 2,
    "enabled": true,
    "scopes": [
      "/subscriptions/{sub-id}/resourceGroups/rg-workshop-production/providers/Microsoft.Web/sites/workshop-app-production"
    ],
    "evaluationFrequency": "PT1M",
    "windowSize": "PT5M",
    "criteria": {
      "odata.type": "Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria",
      "allOf": [
        {
          "name": "Http5xx",
          "metricName": "Http5xx",
          "operator": "GreaterThan",
          "threshold": 5,
          "timeAggregation": "Total"
        }
      ]
    },
    "actions": [
      {
        "actionGroupId": "/subscriptions/{sub-id}/resourceGroups/rg-workshop-production/providers/Microsoft.Insights/actionGroups/security-team"
      }
    ]
  }
}
```

### Alerta: Tasa alta de autenticacion fallida

1. Crear un **Log Alert** basado en query de Application Insights
2. Signal: Custom Log Search

```kql title="KQL Query: Autenticacion fallida"
requests
| where url endswith "/login"
| where resultCode == "401"
| summarize FailedLogins = count() by bin(timestamp, 5m)
| where FailedLogins > 20
```

| Campo | Valor |
|-------|-------|
| Query | (la de arriba) |
| Threshold | > 0 resultados |
| Frequency | Every 5 minutes |
| Alert rule name | `Brute Force Detection - Production` |
| Severity | Sev 1 (Error) |

!!! warning "Application Insights requerido"
    Para las alertas basadas en logs necesitas Application Insights habilitado en el App Service. En el workshop esto es opcional; las alertas de metricas funcionan sin Application Insights.

### Alerta: Requests a endpoints sensibles

```kql title="KQL Query: Acceso a endpoints admin"
requests
| where url contains "/admin"
| where resultCode == "200"
| summarize AdminAccess = count() by bin(timestamp, 1h), client_IP
| where AdminAccess > 10
```

## 1.3 Action Groups

Crea un Action Group para notificar al equipo de seguridad:

1. En Azure Portal > **Monitor** > **Alerts** > **Action groups**
2. Click en **+ Create**
3. Configura:

| Campo | Valor |
|-------|-------|
| Name | `security-team-alerts` |
| Short name | `sec-alerts` |
| Notifications | Email: equipo-seguridad@entelgy.com |
| Notifications | SMS: +34 xxx (opcional) |
| Actions | Azure DevOps Work Item (opcional) |

!!! tip "Integracion con Azure DevOps"
    Puedes configurar el Action Group para que cree automaticamente un Work Item en Azure DevOps cuando se dispare una alerta. Esto conecta la monitorizacion directamente con el backlog del equipo.

## 1.4 Resumen de alertas configuradas

| Alerta | Metrica/Log | Umbral | Severidad | Accion |
|--------|-------------|--------|-----------|--------|
| HTTP 500 Spike | Http5xx metric | > 5 en 5 min | Sev 2 | Email + Ticket |
| Brute Force | Login failures (log) | > 20 en 5 min | Sev 1 | Email + SMS |
| Admin Access | /admin requests (log) | > 10 en 1 hora | Sev 2 | Email |
| Response Time | Avg response time | > 2s | Sev 3 | Email |

!!! success "Paso Completado"
    Has agregado el stage Monitor al pipeline con health checks, smoke tests y tests de rendimiento. Tambien has configurado alertas en Azure Monitor para detectar eventos de seguridad en produccion. En el siguiente paso construiremos un dashboard de seguridad.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="index.md" class="md-button">Anterior: Introduccion</a>
  <a href="step2.md" class="md-button md-button--primary">Siguiente: Dashboard de Seguridad</a>
</div>
