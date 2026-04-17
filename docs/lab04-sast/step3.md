---
tags:
  - lab
  - sast
  - semgrep
  - reglas-personalizadas
---

# Paso 3 -- Reglas Personalizadas

!!! abstract "Objetivo"
    Usar la regla personalizada de Entelgy definida en `vulnerable-app/.semgrep/rules/entelgy.yml`, configurar umbrales de severidad para el pipeline y probar la deteccion con una vulnerabilidad intencional.

## 3.1 Examinar la regla personalizada

El repositorio incluye reglas personalizadas en `vulnerable-app/.semgrep/rules/entelgy.yml`:

```yaml title="vulnerable-app/.semgrep/rules/entelgy.yml"
rules:
  - id: entelgy-no-print-sensitive
    patterns:
      - pattern: print(..., $VAR, ...)
      - metavariable-regex:
          metavariable: $VAR
          regex: ".*(password|token|secret|key|credential).*"
    message: |
      Posible impresion de datos sensibles: '$VAR'.
      Usa logging estructurado con masking en lugar de print().
    languages: [python]
    severity: WARNING
    metadata:
      category: security
      cwe: CWE-312
      confidence: MEDIUM

  - id: entelgy-no-hardcoded-secrets
    patterns:
      - pattern: $VAR = "..."
      - metavariable-regex:
          metavariable: $VAR
          regex: ".*(SECRET|KEY|PASSWORD|TOKEN|CREDENTIAL).*"
    message: |
      Credencial embebida en codigo: '$VAR'.
      Usa variables de entorno o un gestor de secretos (Azure Key Vault).
    languages: [python]
    severity: ERROR
    metadata:
      category: security
      cwe: CWE-798
      confidence: HIGH
```

### Anatomia de las reglas

**Regla 1: `entelgy-no-print-sensitive`**

- **Patron**: Busca llamadas a `print()` donde algun argumento contiene palabras como `password`, `token`, `secret`, etc.
- **Severidad**: WARNING
- **CWE**: CWE-312 (Cleartext Storage of Sensitive Information)

**Regla 2: `entelgy-no-hardcoded-secrets`**

- **Patron**: Busca asignaciones de strings a variables cuyo nombre contiene `SECRET`, `KEY`, `PASSWORD`, etc.
- **Severidad**: ERROR
- **CWE**: CWE-798 (Use of Hard-coded Credentials)

!!! tip "Metavariable-regex"
    Semgrep usa `metavariable-regex` para combinar pattern matching (estructura del codigo) con regex (contenido del texto). Esto es mas preciso que solo regex, porque entiende la estructura del lenguaje.

## 3.2 Ejecutar con reglas personalizadas localmente

```bash title="Terminal"
semgrep scan \
  --config vulnerable-app/.semgrep/rules/entelgy.yml \
  vulnerable-app/
```

### Salida esperada

```text title="Hallazgos de reglas Entelgy"
  vulnerable-app/src/api/users.py
    entelgy-no-hardcoded-secrets
      Credencial embebida en codigo: 'ADMIN_API_KEY'.
      Usa variables de entorno o un gestor de secretos (Azure Key Vault).

      4│ ADMIN_API_KEY = "sk-entelgy-4f8a2b1c9d3e7f6a0b5c8d2e1f4a7b3c"

    entelgy-no-hardcoded-secrets
      Credencial embebida en codigo: 'INTERNAL_SECRET'.
      Usa variables de entorno o un gestor de secretos (Azure Key Vault).

      5│ INTERNAL_SECRET = "db_password=Entelgy2024!Prod"
```

## 3.3 Combinar reglas personalizadas con rulesets publicos

Ejecuta un escaneo combinado:

```bash title="Terminal"
semgrep scan \
  --config p/owasp-top-ten \
  --config p/secrets \
  --config vulnerable-app/.semgrep/rules/entelgy.yml \
  vulnerable-app/
```

Esto ejecuta las reglas publicas **y** las personalizadas en una sola pasada.

## 3.4 Actualizar el stage SAST para incluir reglas personalizadas

Modifica el stage SAST en `azure-pipelines.yml` para incluir las reglas de Entelgy:

```yaml title="azure-pipelines.yml — stage SAST actualizado"
  # ──────────────────────────────────────────────
  # Stage 2: SAST - Analisis Estatico (Semgrep)
  # ──────────────────────────────────────────────
  - stage: SAST
    displayName: 'SAST - Analisis Estatico'
    dependsOn: SecretsDetection
    jobs:
      - job: Semgrep
        displayName: 'Semgrep - Analisis SAST'
        steps:
          - checkout: self
            displayName: 'Checkout del repositorio'

          - script: |
              echo "=== Semgrep — Analisis Estatico de Seguridad ==="
              echo "Rulesets: p/owasp-top-ten, p/secrets, reglas Entelgy"
              echo ""

              docker run --rm \
                -v "$(Build.SourcesDirectory):/src" \
                semgrep/semgrep:latest \
                semgrep scan \
                  --config p/owasp-top-ten \
                  --config p/secrets \
                  --config /src/$(appDirectory)/.semgrep/rules/entelgy.yml \
                  --sarif \
                  --output /src/semgrep-report.sarif \
                  --severity ERROR \
                  /src/$(appDirectory)/

              SEMGREP_EXIT=$?

              echo ""
              echo "Semgrep exit code: $SEMGREP_EXIT"

              # Resumen
              if [ -f "$(Build.SourcesDirectory)/semgrep-report.sarif" ]; then
                python3 -c "
import json
with open('$(Build.SourcesDirectory)/semgrep-report.sarif') as f:
    data = json.load(f)
    results = data.get('runs', [{}])[0].get('results', [])
    errors = sum(1 for r in results if r.get('level') == 'error')
    warnings = sum(1 for r in results if r.get('level') == 'warning')
    print(f'')
    print(f'=== Resumen SAST ===')
    print(f'Total: {len(results)} hallazgos')
    print(f'  Errores:  {errors}')
    print(f'  Warnings: {warnings}')
    if errors > 0:
        print(f'')
        print(f'Hallazgos de severidad ERROR:')
        for r in results:
            if r.get('level') == 'error':
                loc = r['locations'][0]['physicalLocation']
                print(f'  - {r[\"ruleId\"]} en {loc[\"artifactLocation\"][\"uri\"]}:{loc[\"region\"][\"startLine\"]}')
"
              fi

              exit $SEMGREP_EXIT
            displayName: 'Ejecutar Semgrep (OWASP + Entelgy)'
            continueOnError: false

          - task: PublishBuildArtifacts@1
            displayName: 'Publicar reporte SARIF'
            inputs:
              PathtoPublish: '$(Build.SourcesDirectory)/semgrep-report.sarif'
              ArtifactName: 'SecurityReports-Semgrep'
              publishLocation: 'Container'
            condition: always()
```

### Cambios clave

1. **`--config /src/$(appDirectory)/.semgrep/rules/entelgy.yml`** -- Agrega las reglas personalizadas de Entelgy
2. **`--severity ERROR`** -- Solo reporta hallazgos de severidad ERROR (falla solo con errores criticos)

## 3.5 Configurar umbrales de severidad

El flag `--severity` controla que nivel de severidad hace que Semgrep reporte hallazgos:

| Flag | Comportamiento |
|------|---------------|
| `--severity ERROR` | Solo reporta errores criticos |
| `--severity WARNING` | Reporta errores y warnings |
| `--severity INFO` | Reporta todo (mas ruidoso) |
| *(sin flag)* | Reporta todo por defecto |

!!! tip "Estrategia recomendada"
    Para pipelines de produccion, recomendamos:

    - **CI en ramas de feature**: `--severity WARNING` (mas estricto para desarrollo)
    - **CI en main**: `--severity ERROR` (solo bloquea en criticos)
    - **Escaneos periodicos**: `--severity INFO` (revision completa semanal)

Puedes implementar esta logica condicional en el pipeline:

```yaml title="Severidad condicional (ejemplo)"
          - script: |
              if [ "$(Build.SourceBranchName)" = "main" ]; then
                SEVERITY="ERROR"
              else
                SEVERITY="WARNING"
              fi

              docker run --rm \
                -v "$(Build.SourcesDirectory):/src" \
                semgrep/semgrep:latest \
                semgrep scan \
                  --config p/owasp-top-ten \
                  --config p/secrets \
                  --config /src/$(appDirectory)/.semgrep/rules/entelgy.yml \
                  --sarif \
                  --output /src/semgrep-report.sarif \
                  --severity $SEVERITY \
                  /src/$(appDirectory)/
            displayName: 'Semgrep con severidad condicional'
```

## 3.6 Probar con una vulnerabilidad intencional

Crea una rama y agrega una vulnerabilidad para probar:

```bash title="Terminal"
git checkout -b feature/test-sast

# Crear archivo con vulnerabilidad intencional
cat > vulnerable-app/src/utils/test_vuln.py << 'PYEOF'
import subprocess

API_TOKEN = "ghp_fake_token_for_testing_12345678901234"

def execute_command(user_input):
    """VULNERABLE: Command Injection (CWE-78)"""
    result = subprocess.call(user_input, shell=True)
    return result

def log_credentials(password):
    """VULNERABLE: Logging sensitive data (CWE-312)"""
    print("User password is:", password)
    return True
PYEOF
```

Ejecuta Semgrep localmente:

```bash title="Terminal"
semgrep scan \
  --config p/owasp-top-ten \
  --config p/secrets \
  --config vulnerable-app/.semgrep/rules/entelgy.yml \
  vulnerable-app/src/utils/test_vuln.py
```

Deberia detectar:

- **Command Injection** (`subprocess.call` con `shell=True` y entrada de usuario)
- **Hardcoded token** (regla de `p/secrets`)
- **Print de datos sensibles** (regla `entelgy-no-print-sensitive`)

Limpia despues:

```bash title="Terminal"
rm vulnerable-app/src/utils/test_vuln.py
git checkout main
git branch -d feature/test-sast
```

## 3.7 Escribir tu propia regla Semgrep

Como ejercicio, intenta escribir una regla que detecte el uso de `debug=True` en Flask:

```yaml title="Ejemplo: regla personalizada"
rules:
  - id: entelgy-no-flask-debug
    pattern: app.run(..., debug=True, ...)
    message: |
      Flask ejecutandose con debug=True. Esto expone el
      debugger interactivo de Werkzeug en produccion (CWE-489).
    languages: [python]
    severity: ERROR
    metadata:
      cwe: CWE-489
      category: security
```

Puedes agregar esta regla a `vulnerable-app/.semgrep/rules/entelgy.yml` y verificar que detecta la linea 72 de `vulnerable-app/app.py`:

```python
app.run(host="0.0.0.0", port=8080, debug=True)
```

!!! info "Semgrep Playground"
    Puedes probar y depurar reglas de Semgrep en [semgrep.dev/playground](https://semgrep.dev/playground). Es muy util para iterar rapidamente sin necesidad de ejecutar localmente.

## 3.8 Hacer push del stage actualizado

```bash title="Terminal"
git add azure-pipelines.yml
git commit -m "lab04: agregar reglas Entelgy y configurar severidad en SAST"
git push origin main
```

!!! success "Paso Completado"
    Has integrado las reglas personalizadas de Entelgy en el pipeline, configurado umbrales de severidad y probado la deteccion con vulnerabilidades intencionales. El stage SAST ahora ejecuta reglas publicas (OWASP Top 10 + Secrets) y personalizadas.

## Resumen del Lab 4

| Concepto | Detalle |
|----------|---------|
| **Herramienta** | Semgrep (open source) |
| **Stage** | `SAST` (segundo en el pipeline) |
| **Rulesets** | `p/owasp-top-ten`, `p/secrets`, reglas Entelgy |
| **Artefacto** | `semgrep-report.sarif` |
| **Vulnerabilidades** | SQLi, XSS, hardcoded secrets, weak crypto |
| **Reglas custom** | `entelgy-no-print-sensitive`, `entelgy-no-hardcoded-secrets` |

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../step2/" class="md-button">Anterior: Paso 2</a>
  <a href="../../lab05-sca/" class="md-button md-button--primary">Siguiente: Lab 5</a>
</div>
