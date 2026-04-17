---
tags:
  - lab
  - sast
  - semgrep
---

# Paso 1 -- Semgrep Local

!!! abstract "Objetivo"
    Instalar Semgrep, ejecutarlo contra `vulnerable-app/`, identificar las vulnerabilidades de SQL Injection, XSS, secretos hardcodeados y criptografia debil, y mapear cada hallazgo a su CWE y categoria OWASP Top 10.

## 1.1 Instalar Semgrep

=== "pip (Recomendado)"

    ```bash title="Terminal"
    pip install semgrep
    ```

=== "Homebrew (macOS)"

    ```bash title="Terminal"
    brew install semgrep
    ```

=== "Docker"

    ```bash title="Terminal"
    docker pull semgrep/semgrep:latest
    ```

Verifica la instalacion:

```bash title="Terminal"
semgrep --version
```

## 1.2 Primer escaneo con reglas OWASP Top 10

Ejecuta Semgrep con el ruleset de OWASP Top 10:

```bash title="Terminal"
semgrep scan \
  --config p/owasp-top-ten \
  vulnerable-app/
```

### Salida esperada

Semgrep deberia detectar multiples vulnerabilidades. Veamos las principales:

#### SQL Injection en `src/auth/login.py`

```text title="Hallazgo: SQL Injection (CWE-89)"
  vulnerable-app/src/auth/login.py
    python.lang.security.audit.formatted-sql-query
      Detected string formatting in a SQL query. This could lead to
      SQL injection if user input is used. Use parameterized queries instead.

      17│ query = f"SELECT * FROM users WHERE username = '{username}' AND password = '{password}'"

      34│ f"INSERT INTO users (username, password, email) VALUES ('{username}', '{password}', '{email}')"
```

!!! warning "SQL Injection"
    Las f-strings en consultas SQL permiten a un atacante inyectar SQL arbitrario. Por ejemplo, un `username` como `' OR 1=1 --` devolveria todos los usuarios, y `'; DROP TABLE users; --` podria borrar la tabla completa.

#### XSS en `src/views/search.py`

```text title="Hallazgo: XSS (CWE-79)"
  vulnerable-app/src/views/search.py
    python.flask.security.xss.audit.direct-use-of-jinja2
      Detected user input flowing into a Jinja2 template via
      render_template_string. This may lead to XSS.

      9│ template = f"""
      ...
      15│     <p>Búsqueda: {query}</p>
```

La variable `query` viene directamente de `request.args.get("q")` sin ningun tipo de sanitizacion y se interpola en el HTML.

#### Criptografia debil en `src/utils/crypto.py`

```text title="Hallazgo: Weak Crypto (CWE-327)"
  vulnerable-app/src/utils/crypto.py
    python.lang.security.audit.insecure-hash-function.insecure-md5-hash
      Detected MD5 hash algorithm. MD5 is considered broken and
      should not be used for security purposes.

      8│ return hashlib.md5(password.encode()).hexdigest()
```

## 1.3 Escaneo con reglas de secretos

Ejecuta un segundo escaneo con el ruleset de secretos:

```bash title="Terminal"
semgrep scan \
  --config p/secrets \
  vulnerable-app/
```

Esto encontrara los secretos hardcodeados en `src/api/users.py`:

```text title="Hallazgo: Hardcoded Secrets (CWE-798)"
  vulnerable-app/src/api/users.py
    python.lang.security.audit.hardcoded-password
      Detected hardcoded credentials.

      4│ ADMIN_API_KEY = "sk-entelgy-4f8a2b1c9d3e7f6a0b5c8d2e1f4a7b3c"
      5│ INTERNAL_SECRET = "db_password=Entelgy2024!Prod"
```

## 1.4 Escaneo combinado con multiples rulesets

Puedes combinar multiples rulesets en un solo escaneo:

```bash title="Terminal"
semgrep scan \
  --config p/owasp-top-ten \
  --config p/secrets \
  --config p/python \
  --json \
  --output semgrep-results.json \
  vulnerable-app/
```

Para ver un resumen rapido:

```bash title="Terminal"
semgrep scan \
  --config p/owasp-top-ten \
  --config p/secrets \
  vulnerable-app/ \
  2>&1 | tail -20
```

La salida final muestra un resumen:

```text title="Resumen de Semgrep"
Findings:

  python.lang.security.audit.formatted-sql-query         2 findings
  python.flask.security.xss.audit.direct-use-of-jinja2   1 finding
  python.lang.security.audit.insecure-hash-function       1 finding
  python.lang.security.audit.hardcoded-password           2 findings
  generic.secrets.security.detected-generic-api-key       1 finding

Ran 1247 rules on 6 files: 7+ findings.
```

## 1.5 Mapeo de hallazgos a CWE y OWASP Top 10

| Hallazgo | Archivo | CWE | OWASP Top 10 | Severidad |
|----------|---------|-----|--------------|-----------|
| SQL Injection (login) | `src/auth/login.py:18` | CWE-89 | A03:2021 Injection | **ERROR** |
| SQL Injection (register) | `src/auth/login.py:34` | CWE-89 | A03:2021 Injection | **ERROR** |
| Reflected XSS | `src/views/search.py:9` | CWE-79 | A03:2021 Injection | **WARNING** |
| Hardcoded API Key | `src/api/users.py:4` | CWE-798 | A07:2021 Identification | **ERROR** |
| Hardcoded Password | `src/api/users.py:5` | CWE-798 | A07:2021 Identification | **ERROR** |
| MD5 Hash | `src/utils/crypto.py:8` | CWE-327 | A02:2021 Crypto Failures | **WARNING** |
| Base64 "Encryption" | `src/utils/crypto.py:18` | CWE-326 | A02:2021 Crypto Failures | **WARNING** |
| Debug Mode | `app.py:13` | CWE-489 | A05:2021 Misconfig | **WARNING** |

## 1.6 Generar reporte SARIF

Genera el reporte en formato SARIF para el pipeline:

```bash title="Terminal"
semgrep scan \
  --config p/owasp-top-ten \
  --config p/secrets \
  --sarif \
  --output semgrep-report.sarif \
  vulnerable-app/
```

Verifica el contenido:

```bash title="Terminal"
python3 -c "
import json
with open('semgrep-report.sarif') as f:
    data = json.load(f)
    results = data['runs'][0]['results']
    print(f'Total hallazgos: {len(results)}')
    for r in results:
        print(f'  [{r[\"level\"]}] {r[\"ruleId\"]} — {r[\"locations\"][0][\"physicalLocation\"][\"artifactLocation\"][\"uri\"]}')
"
```

!!! tip "Severidades en Semgrep"
    Semgrep usa tres niveles de severidad:

    - **ERROR** -- Vulnerabilidades criticas que deben corregirse (SQLi, secretos hardcodeados)
    - **WARNING** -- Problemas importantes pero menos criticos (hash debil, debug mode)
    - **INFO** -- Sugerencias y mejores practicas

!!! success "Paso Completado"
    Has ejecutado Semgrep localmente y encontrado las principales vulnerabilidades en `vulnerable-app/`: SQL Injection, XSS, secretos hardcodeados y criptografia debil. Cada hallazgo esta mapeado a su CWE y categoria OWASP Top 10.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../" class="md-button">Volver al Lab 4</a>
  <a href="../step2/" class="md-button md-button--primary">Paso 2: Añadir Stage SAST</a>
</div>
