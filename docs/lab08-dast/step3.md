---
tags:
  - lab
  - dast
  - owasp-zap
  - falsos-positivos
---

# Paso 3 -- Analisis del Reporte y Ajuste

!!! abstract "Objetivo"
    Interpretar el reporte de OWASP ZAP, configurar un archivo de reglas para gestionar falsos positivos, y establecer un gate que falle el pipeline cuando se detecten vulnerabilidades High.

## 3.1 Interpretar el reporte ZAP

El reporte HTML de ZAP organiza los hallazgos por nivel de riesgo:

| Nivel | Color | Significado | Accion |
|-------|-------|-------------|--------|
| **High** | Rojo | Vulnerabilidad explotable confirmada | Corregir antes de desplegar |
| **Medium** | Naranja | Vulnerabilidad probable o configuracion insegura | Evaluar y planificar correccion |
| **Low** | Amarillo | Riesgo menor o buena practica faltante | Corregir cuando sea posible |
| **Informational** | Azul | Informacion tecnica, no es vulnerabilidad | Revisar para contexto |

### Hallazgos esperados en nuestra app

**High Risk:**

```text title="Ejemplo: SQL Injection detectada por ZAP"
Alert: SQL Injection
Risk: High
Confidence: Medium
URL: http://localhost:8080/login
Parameter: username
Attack: ' OR '1'='1
Evidence: Error message containing SQL syntax
CWE: 89 — Improper Neutralization of Special Elements in SQL Command
```

```text title="Ejemplo: XSS Reflejado detectado por ZAP"
Alert: Cross Site Scripting (Reflected)
Risk: High
Confidence: High
URL: http://localhost:8080/search?q=%3Cscript%3Ealert%281%29%3C%2Fscript%3E
Parameter: q
Attack: <script>alert(1)</script>
Evidence: <script>alert(1)</script>
CWE: 79 — Improper Neutralization of Input During Web Page Generation
```

**Medium Risk:**

```text title="Ejemplo: Headers de seguridad faltantes"
Alert: Content Security Policy (CSP) Header Not Set
Risk: Medium
URL: http://localhost:8080/
CWE: 693 — Protection Mechanism Failure

Alert: Missing Anti-clickjacking Header
Risk: Medium
URL: http://localhost:8080/
CWE: 1021 — Improper Restriction of Rendered UI Layers
```

!!! tip "Correlacionar con SAST"
    Compara los hallazgos de ZAP con los del Lab 4 (SAST con Semgrep). El SQL Injection en `/login` fue detectado por ambas herramientas, pero desde perspectivas diferentes: SAST vio el patron de codigo inseguro, DAST confirmo que es explotable.

## 3.2 Configurar reglas de exclusion

ZAP permite definir reglas en un archivo TSV (Tab-Separated Values) para controlar como se manejan alertas especificas:

```text title="vulnerable-app/.zap/rules.tsv"
# Formato: <ID_regla>\t<accion>
# Acciones: IGNORE, WARN, FAIL
# Tab como separador (no espacios)

# Ignorar: alertas informativas que no aplican a nuestra app
10021	IGNORE	# International Domain Name (no aplica)
10036	IGNORE	# Server Leaks Version (lo corregiremos en Nginx config)

# Warn: alertas que queremos ver pero no bloquear (aun)
10038	WARN	# Content Security Policy - se implementara en fase 2
10020	WARN	# X-Frame-Options - se implementara en fase 2

# Fail: alertas criticas que deben bloquear el pipeline
40012	FAIL	# Cross Site Scripting (Reflected)
40018	FAIL	# SQL Injection
40014	FAIL	# Cross Site Scripting (Persistent)
90021	FAIL	# XPath Injection
90018	FAIL	# Advanced SQL Injection
```

!!! warning "No silenciar vulnerabilidades reales"
    Usa `IGNORE` solo para falsos positivos confirmados, nunca para vulnerabilidades que simplemente no quieres ver. La gestion de falsos positivos debe documentarse y revisarse periodicamente.

## 3.3 Usar el archivo de reglas en ZAP

Modifica los comandos de ZAP en el pipeline para incluir el archivo de reglas:

```yaml title="vulnerable-app/.github/workflows/devsecops.yml -- ZAP con reglas de exclusion"
          # --- ZAP Baseline con reglas ---
          - run: |
              mkdir -p ${{ github.workspace }}/zap-reports
              docker run --rm \
                --network host \
                -v ${{ github.workspace }}/zap-reports:/zap/wrk:rw \
                -v ${{ github.workspace }}/vulnerable-app/.zap:/zap/rules:ro \
                -t ghcr.io/zaproxy/zaproxy:stable \
                zap-baseline.py \
                  -t http://localhost:8080 \
                  -r zap-baseline-report.html \
                  -J zap-baseline-report.json \
                  -c /zap/rules/rules.tsv
            name: 'ZAP Baseline (con reglas)'
            continue-on-error: true

          # --- ZAP Full Scan con reglas ---
          - run: |
              docker run --rm \
                --network host \
                -v ${{ github.workspace }}/zap-reports:/zap/wrk:rw \
                -v ${{ github.workspace }}/vulnerable-app/.zap:/zap/rules:ro \
                -t ghcr.io/zaproxy/zaproxy:stable \
                zap-full-scan.py \
                  -t http://localhost:8080 \
                  -r zap-full-report.html \
                  -J zap-full-report.json \
                  -m 10 \
                  -c /zap/rules/rules.tsv
            name: 'ZAP Full Scan (con reglas)'
            continue-on-error: true
```

El flag `-c` carga el archivo de reglas. Las alertas marcadas como `FAIL` haran que ZAP retorne exit code distinto de 0.

## 3.4 Gate mejorado con parsing del reporte

Un gate mas robusto que analiza el JSON y genera un resumen:

```yaml title="vulnerable-app/.github/workflows/devsecops.yml -- Gate mejorado"
          # --- Gate DAST: Evaluar resultados ---
          - run: |
              echo "=== Evaluando resultados DAST ==="
              echo ""

              REPORT="${{ github.workspace }}/zap-reports/zap-full-report.json"

              if [ ! -f "$REPORT" ]; then
                echo "WARN: Reporte no encontrado, saltando gate"
                exit 0
              fi

              # Analizar el reporte con Python
              python3 << 'PYEOF'
              import json
              import sys

              with open("${{ github.workspace }}/zap-reports/zap-full-report.json") as f:
                  data = json.load(f)

              sites = data.get("site", [])
              if not sites:
                  print("No se encontraron sitios en el reporte")
                  sys.exit(0)

              alerts = sites[0].get("alerts", [])

              # Clasificar por riesgo
              risk_map = {"0": "Informational", "1": "Low", "2": "Medium", "3": "High"}
              summary = {"High": [], "Medium": [], "Low": [], "Informational": []}

              for alert in alerts:
                  risk = risk_map.get(alert.get("riskcode", "0"), "Unknown")
                  summary[risk].append(alert.get("alert", "Unknown"))

              # Imprimir resumen
              print("=" * 60)
              print("RESUMEN DAST - OWASP ZAP")
              print("=" * 60)
              for level in ["High", "Medium", "Low", "Informational"]:
                  count = len(summary[level])
                  print(f"\n{level}: {count} alerta(s)")
                  for name in summary[level]:
                      print(f"  - {name}")

              print("\n" + "=" * 60)

              # Gate: fallar si hay High
              high_count = len(summary["High"])
              if high_count > 0:
                  print(f"\nFAIL: {high_count} alertas de riesgo High encontradas")
                  print("El pipeline deberia bloquearse en un entorno real")
                  # Descomentar para activar el gate:
                  # sys.exit(1)
              else:
                  print("\nPASS: No se encontraron alertas High")
              PYEOF
            name: 'DAST Gate (High alerts)'
            continue-on-error: true
```

## 3.5 Crear el archivo de reglas

Crea el directorio y archivo de reglas en el repositorio:

```bash title="Crear archivo de reglas ZAP"
mkdir -p vulnerable-app/.zap

cat > vulnerable-app/.zap/rules.tsv << 'EOF'
# ZAP Scan Rules Configuration
# Format: <rule_id>\t<action>
# Actions: IGNORE, WARN, FAIL
#
# Gestionado por el equipo de seguridad
# Ultima revision: 2026-04-08

# === FAIL: Vulnerabilidades criticas ===
40012	FAIL	# XSS (Reflected)
40014	FAIL	# XSS (Persistent)
40018	FAIL	# SQL Injection
90021	FAIL	# XPath Injection
90018	FAIL	# Advanced SQL Injection
40003	FAIL	# CRLF Injection
40008	FAIL	# Parameter Tampering
40032	FAIL	# .htaccess Information Leak
40009	FAIL	# Server Side Include
40029	FAIL	# Trace.axd Information Leak

# === WARN: Requieren atencion pero no bloquean ===
10038	WARN	# Content Security Policy
10020	WARN	# X-Frame-Options
10035	WARN	# Strict-Transport-Security
10098	WARN	# Cross-Domain Misconfiguration

# === IGNORE: Falsos positivos confirmados ===
10021	IGNORE	# International Domain Name
10036	IGNORE	# Server Leaks Version Info via Server HTTP Response Header
EOF
```

## 3.6 Comparacion baseline vs full scan

| Aspecto | Baseline | Full Scan |
|---------|----------|-----------|
| **Duracion** | ~2 minutos | ~10 minutos |
| **Tipo de analisis** | Pasivo | Pasivo + Activo |
| **SQL Injection** | No detecta | Detecta (envia payloads) |
| **XSS** | Puede detectar reflejado simple | Detecta con multiples payloads |
| **Headers faltantes** | Detecta | Detecta |
| **Uso recomendado** | CI en cada commit | Pre-release / periodico |

!!! tip "Estrategia progresiva"
    Ejecuta el baseline en cada push (rapido, no invasivo). El full scan puede ejecutarse de forma programada (ej: nightly) o solo en la rama `main` antes de release.

## 3.7 Resumen de seguridad del Lab 8

| Control | Implementacion | Estado |
|---------|---------------|--------|
| Aplicacion en ejecucion | Docker Compose en el agente | Automatizado |
| Escaneo pasivo | ZAP baseline scan | En cada pipeline run |
| Escaneo activo | ZAP full scan | En cada pipeline run |
| Gestion de falsos positivos | `.zap/rules.tsv` | Versionado en el repo |
| Gate de seguridad | Falla en alertas High | Configurable |
| Reportes | HTML + JSON como artefactos | Descargables |

!!! success "Paso Completado"
    Has completado el Lab 8. Tu pipeline ahora incluye escaneo DAST con OWASP ZAP, con gestion de falsos positivos y un gate configurable. La combinacion de SAST (Lab 4) + DAST (Lab 8) proporciona cobertura de seguridad tanto estatica como dinamica.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="step2.md" class="md-button">Anterior: Escaneo ZAP</a>
  <a href="../lab09-iac/index.md" class="md-button md-button--primary">Siguiente: Lab 9 -- IaC Scan</a>
</div>
