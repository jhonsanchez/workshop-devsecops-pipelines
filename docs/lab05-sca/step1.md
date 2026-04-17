---
tags:
  - lab
  - sca
  - trivy
  - sbom
  - cyclonedx
---

# Paso 1 -- Trivy FS y SBOM Local

!!! abstract "Objetivo"
    Ejecutar `trivy fs` localmente contra `vulnerable-app/` para detectar CVEs en las dependencias de `requirements.txt` y generar un SBOM en formato CycloneDX.

## 1.1 Instalar Trivy

=== "macOS (Homebrew)"

    ```bash title="Terminal"
    brew install trivy
    ```

=== "Linux"

    ```bash title="Terminal"
    sudo apt-get install wget apt-transport-https gnupg lsb-release
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
    echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee /etc/apt/sources.list.d/trivy.list
    sudo apt-get update
    sudo apt-get install trivy
    ```

=== "Docker"

    ```bash title="Terminal"
    docker pull aquasec/trivy:latest
    ```

Verifica la instalacion:

```bash title="Terminal"
trivy version
```

## 1.2 Escanear dependencias con trivy fs

Ejecuta Trivy en modo filesystem para analizar `requirements.txt`:

```bash title="Terminal"
trivy fs vulnerable-app/ --severity HIGH,CRITICAL
```

### Salida esperada

```text title="Salida de Trivy fs"
vulnerable-app/requirements.txt (pip)

Total: 15 (HIGH: 9, CRITICAL: 6)

┌───────────────┬────────────────┬──────────┬────────┬───────────────────┬───────────────┬──────────────────────────────────────┐
│    Library    │ Vulnerability  │ Severity │ Status │ Installed Version │ Fixed Version │                Title                 │
├───────────────┼────────────────┼──────────┼────────┼───────────────────┼───────────────┼──────────────────────────────────────┤
│ PyYAML        │ CVE-2020-14343 │ CRITICAL │ fixed  │ 5.3.1             │ 5.4           │ Arbitrary code execution via         │
│               │                │          │        │                   │               │ yaml.load()                          │
├───────────────┼────────────────┼──────────┼────────┼───────────────────┼───────────────┼──────────────────────────────────────┤
│ Werkzeug      │ CVE-2023-25577 │ HIGH     │ fixed  │ 2.0.1             │ 2.2.3         │ High resource usage when parsing     │
│               │                │          │        │                   │               │ multipart form data                  │
├───────────────┼────────────────┼──────────┼────────┼───────────────────┼───────────────┼──────────────────────────────────────┤
│ Werkzeug      │ CVE-2023-23934 │ HIGH     │ fixed  │ 2.0.1             │ 2.2.3         │ Cookie parsing issue on localhost    │
├───────────────┼────────────────┼──────────┼────────┼───────────────────┼───────────────┼──────────────────────────────────────┤
│ requests      │ CVE-2023-32681 │ HIGH     │ fixed  │ 2.25.0            │ 2.31.0        │ Unintended leak of Proxy-Auth        │
│               │                │          │        │                   │               │ header                               │
├───────────────┼────────────────┼──────────┼────────┼───────────────────┼───────────────┼──────────────────────────────────────┤
│ cryptography  │ CVE-2023-49083 │ HIGH     │ fixed  │ 3.3.2             │ 41.0.6        │ NULL pointer dereference in PKCS12   │
│               │                │          │        │                   │               │ parsing                              │
├───────────────┼────────────────┼──────────┼────────┼───────────────────┼───────────────┼──────────────────────────────────────┤
│ Jinja2        │ CVE-2024-22195 │ CRITICAL │ fixed  │ 3.0.1             │ 3.1.3         │ XSS via xmlattr filter               │
└───────────────┴────────────────┴──────────┴────────┴───────────────────┴───────────────┴──────────────────────────────────────┘
```

!!! warning "CVEs reales"
    Estas son vulnerabilidades **reales** en versiones antiguas de paquetes populares de Python. En un proyecto real, deberias actualizar inmediatamente a las versiones parcheadas.

## 1.3 Entender la salida

Cada fila del reporte contiene:

| Campo | Descripcion |
|-------|-------------|
| **Library** | Nombre del paquete afectado |
| **Vulnerability** | ID de la CVE |
| **Severity** | CRITICAL, HIGH, MEDIUM o LOW |
| **Status** | `fixed` (hay parche disponible) o `affected` |
| **Installed Version** | Version en `requirements.txt` |
| **Fixed Version** | Version minima que corrige la CVE |
| **Title** | Descripcion breve de la vulnerabilidad |

!!! tip "Filtrar por severidad"
    Usa `--severity` para filtrar:

    - `--severity CRITICAL` -- Solo criticas
    - `--severity HIGH,CRITICAL` -- Altas y criticas
    - Sin flag -- Todas las severidades

## 1.4 Generar SBOM en formato CycloneDX

Genera un inventario completo de dependencias:

```bash title="Terminal"
trivy fs vulnerable-app/ \
  --format cyclonedx \
  --output sbom-vulnerable-app.json
```

Inspecciona el SBOM generado:

```bash title="Terminal"
python3 -c "
import json
with open('sbom-vulnerable-app.json') as f:
    sbom = json.load(f)
    print(f'Formato: {sbom.get(\"bomFormat\", \"N/A\")}')
    print(f'Version spec: {sbom.get(\"specVersion\", \"N/A\")}')
    components = sbom.get('components', [])
    print(f'Componentes: {len(components)}')
    print()
    for c in components:
        name = c.get('name', 'N/A')
        version = c.get('version', 'N/A')
        purl = c.get('purl', 'N/A')
        print(f'  {name}=={version}')
        print(f'    PURL: {purl}')
"
```

### Estructura del SBOM CycloneDX

```json title="Fragmento de sbom-vulnerable-app.json"
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.5",
  "serialNumber": "urn:uuid:...",
  "version": 1,
  "metadata": {
    "timestamp": "2026-04-08T...",
    "tools": [
      {
        "vendor": "aquasecurity",
        "name": "trivy",
        "version": "0.x.x"
      }
    ]
  },
  "components": [
    {
      "type": "library",
      "name": "Flask",
      "version": "2.0.1",
      "purl": "pkg:pypi/flask@2.0.1",
      "properties": [
        {
          "name": "aquasecurity:trivy:PkgType",
          "value": "pip"
        }
      ]
    },
    {
      "type": "library",
      "name": "Jinja2",
      "version": "3.0.1",
      "purl": "pkg:pypi/jinja2@3.0.1"
    }
  ]
}
```

!!! info "PURL (Package URL)"
    Cada componente tiene un **PURL** (Package URL) que identifica de forma unica el paquete. Ejemplo: `pkg:pypi/flask@2.0.1` indica paquete `flask`, version `2.0.1`, del ecosistema `pypi`.

## 1.5 Escaneo con reporte completo en tabla

Para ver CVEs y SBOM juntos:

```bash title="Terminal"
# Reporte en formato tabla (legible en terminal)
trivy fs vulnerable-app/ --format table

# Reporte en JSON (para procesamiento)
trivy fs vulnerable-app/ --format json --output trivy-report.json
```

## 1.6 Comparar con versiones actualizadas

Para entender el impacto de actualizar las dependencias, puedes crear un `requirements.txt` temporal con versiones actualizadas:

```bash title="Terminal"
cat > /tmp/requirements-fixed.txt << 'EOF'
Flask>=3.0.0
Jinja2>=3.1.3
Werkzeug>=3.0.0
requests>=2.31.0
PyYAML>=6.0.1
cryptography>=42.0.0
gunicorn>=21.2.0
EOF

# Comparar (no ejecutar en el proyecto real)
echo "--- Versiones vulnerables ---"
cat vulnerable-app/requirements.txt
echo ""
echo "--- Versiones corregidas ---"
cat /tmp/requirements-fixed.txt
```

!!! tip "Actualizaciones de dependencias"
    En un proyecto real, usarias herramientas como **Dependabot**, **Renovate** o **pip-audit** para automatizar la actualizacion de dependencias con CVEs conocidas.

!!! success "Paso Completado"
    Has ejecutado Trivy fs localmente, detectado CVEs en las dependencias de `vulnerable-app/` y generado un SBOM en formato CycloneDX.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../" class="md-button">Volver al Lab 5</a>
  <a href="../step2/" class="md-button md-button--primary">Paso 2: Añadir Stage SCA</a>
</div>
