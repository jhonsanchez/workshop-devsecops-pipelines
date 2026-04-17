---
title: "Resultado 10 — Monitorizacion Post-Despliegue"
description: Health checks, smoke tests, verificacion de cabeceras de seguridad y resumen final del pipeline DevSecOps.
tags:
  - Resultados
  - Monitorizacion
  - Health check
  - Smoke tests
  - Pipeline
---

# Stage 10 — Monitorizacion Post-Despliegue

<div class="lab-meta">
  <div class="lab-meta-item">
    <strong>Verificaciones</strong>
    Health + Smoke + Headers
  </div>
  <div class="lab-meta-item">
    <strong>Endpoints probados</strong>
    /, /health, /search?q=test
  </div>
  <div class="lab-meta-item">
    <strong>Resultado</strong>
    Job Summary con tabla final
  </div>
  <div class="lab-meta-item">
    <strong>Warnings esperados</strong>
    Cabeceras de seguridad faltantes
  </div>
</div>

---

## Que hace este stage

Este job levanta la aplicacion y ejecuta tres tipos de verificaciones: un **health check** contra `/health`, **smoke tests** contra los endpoints principales, y una **verificacion de cabeceras de seguridad** HTTP. Al finalizar, genera un **Job Summary** con la tabla resumen de los 10 stages del pipeline.

---

## Output esperado en el log

### Step: Health Checks y Smoke Tests

```text
=== Health Check ===
Health endpoint: 200

=== Smoke Tests ===
  / → 200
  /health → 200
  /search?q=test → 200

=== Verificar cabeceras de seguridad ===
::warning::Falta X-Content-Type-Options
::warning::Falta X-Frame-Options

=== Despliegue verificado ===
```

!!! warning "Warnings de cabeceras son esperados"
    La aplicacion vulnerable **no tiene** cabeceras de seguridad configuradas a proposito. Los warnings `::warning::` aparecen como anotaciones amarillas en el run de GitHub Actions, no fallan el pipeline.

---

## Job Summary esperado

El step final genera la tabla resumen del pipeline completo. Este es el contenido que veras en la pestana **Summary** del run:

```markdown
### Pipeline DevSecOps Completado ✅

| Stage | Herramienta | Estado |
|---|---|---|
| Secretos | Gitleaks | ✅ |
| SAST | Semgrep | ✅ |
| SCA | Trivy FS | ✅ |
| Build | Docker + GHCR | ✅ |
| Image Scan | Trivy + Cosign | ✅ |
| IaC | Checkov | ✅ |
| Staging | Docker Compose | ✅ |
| DAST | OWASP ZAP | ✅ |
| Produccion | Cosign verify + Deploy | ✅ |
| Monitor | Health + Smoke | ✅ |
```

!!! success "Los 10 stages en verde"
    Si ves esta tabla con todos los checks en verde, el pipeline DevSecOps completo se ejecuto correctamente. Todos los hallazgos de seguridad se detectaron y reportaron sin bloquear el flujo (gracias al uso de `soft_fail` y `continue-on-error` donde corresponde).

---

## Donde verificar en GitHub

!!! tip "Verificacion completa"

    1. **Actions** > click en el run > job **10. Verificacion Post-Despliegue** > logs
    2. **Actions** > click en el run > **Summary** > tabla "Pipeline DevSecOps Completado"
    3. En el run, buscar las **anotaciones amarillas** (warnings) sobre cabeceras faltantes
    4. Verificar que el workflow completo muestra **todos los jobs en verde**

---

!!! abstract "Pipeline DevSecOps completo"
    Has recorrido los resultados de los 10 stages. Cada herramienta detecto vulnerabilidades en su capa: secretos, bugs estaticos, dependencias, imagen, infraestructura y vulnerabilidades en runtime. Ese es el valor de un pipeline DevSecOps.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../09-produccion/" class="md-button">:material-arrow-left: 9. Deploy Produccion</a>
  <a href="../" class="md-button md-button--primary">Volver al indice de resultados :material-arrow-right:</a>
</div>
