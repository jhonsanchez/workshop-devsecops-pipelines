---
title: "Resultado 8 — DAST (OWASP ZAP)"
description: Alertas esperadas del escaneo dinamico OWASP ZAP contra la aplicacion vulnerable en ejecucion.
tags:
  - Resultados
  - DAST
  - OWASP ZAP
  - Seguridad dinamica
---

# Stage 8 — DAST (OWASP ZAP)

<div class="lab-meta">
  <div class="lab-meta-item">
    <strong>Herramienta</strong>
    OWASP ZAP (Full Scan)
  </div>
  <div class="lab-meta-item">
    <strong>Objetivo</strong>
    localhost:8080
  </div>
  <div class="lab-meta-item">
    <strong>Artefacto</strong>
    zap-report (HTML + JSON)
  </div>
  <div class="lab-meta-item">
    <strong>Alertas esperadas</strong>
    XSS, SQLi, headers, cookies
  </div>
</div>

---

## Que hace este stage

ZAP levanta la aplicacion con `docker compose`, hace un **spider/crawl** para descubrir endpoints y luego ejecuta un **full scan** (pasivo + activo) contra `http://localhost:8080`. Envia payloads maliciosos a cada parametro descubierto y analiza las respuestas en busca de vulnerabilidades. Los resultados se publican como artefacto descargable.

---

## Alertas esperadas

!!! failure "ZAP reporta multiples alertas de severidad Alta y Media"

| Riesgo | Alerta | CWE | Descripcion |
|---|---|---|---|
| :material-alert: **Alto** | Cross Site Scripting (Reflected) | CWE-79 | El parametro `q` en `/search` refleja input sin sanitizar |
| :material-alert: **Alto** | SQL Injection | CWE-89 | Parametros vulnerables a inyeccion SQL |
| :material-alert-circle: **Medio** | Content Security Policy Header Missing | CWE-693 | Sin cabecera CSP en las respuestas |
| :material-alert-circle: **Medio** | Missing Anti-clickjacking Header | CWE-1021 | Sin `X-Frame-Options` |
| :material-alert-circle: **Medio** | Cookie Without SameSite Attribute | CWE-1275 | Cookies sin atributo SameSite |
| :material-information: **Bajo** | X-Content-Type-Options Header Missing | CWE-693 | Sin cabecera `nosniff` |
| :material-information: **Bajo** | Server Leaks Version Information | CWE-200 | Header Server expone version |
| :material-information: **Info** | Modern Web Application | -- | Detecta tecnologias usadas |

---

## Output esperado en el log

### Step: OWASP ZAP - Full Scan

```text
Using target: http://localhost:8080
Spider scan started...
Active scan started...
WARN-NEW: X-Frame-Options Header Not Set [10020]
WARN-NEW: X-Content-Type-Options Header Missing [10021]
WARN-NEW: Content Security Policy (CSP) Header Not Set [10038]
WARN-NEW: Cookie Without SameSite Attribute [10054]
FAIL-NEW: Cross Site Scripting (Reflected) [40012] x 2
FAIL-NEW: SQL Injection [40018] x 1
FAIL-NEW: 0   FAIL-INPROG: 0   WARN-NEW: 4   WARN-INPROG: 0   INFO: 1   IGNORE: 0   PASS: 28
```

### Step: Evaluar resultados DAST

```text
Alertas High/Critical: 2
```

---

## Artefacto: Reporte ZAP

!!! info "Como descargar el reporte"

    1. **Actions** > click en el run > scroll hasta la seccion **Artifacts**
    2. Descargar el artefacto **`zap-report`**
    3. Dentro encontraras:
        - `report_html.html` — Reporte visual completo (abrir en navegador)
        - `report_json.json` — Datos estructurados para integraciones

---

## Donde verificar en GitHub

!!! tip "Tres puntos de verificacion"

    1. **Actions** > click en el run > job **8. Analisis Dinamico (DAST)** > logs
    2. **Actions** > click en el run > **Artifacts** > `zap-report`
    3. **Actions** > click en el run > **Summary** > seccion "DAST Results"

---

## Por que ZAP encuentra estas alertas

```python
# /search refleja el parametro q sin sanitizar → XSS
@app.route("/search")
def search():
    q = request.args.get("q", "")
    return f"Resultados para: {q}"  # Reflected XSS

# Consulta SQL concatenada directamente → SQLi
query = f"SELECT * FROM users WHERE name = '{username}'"
```

!!! warning "DAST confirma lo que SAST sospechaba"
    SAST (Stage 2) ya detecto estos patrones en el codigo fuente. DAST confirma que son **explotables en runtime**, lo que les da mayor prioridad de remediacion.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../07-staging/" class="md-button">:material-arrow-left: 7. Deploy Staging</a>
  <a href="../09-produccion/" class="md-button md-button--primary">9. Deploy Produccion :material-arrow-right:</a>
</div>
