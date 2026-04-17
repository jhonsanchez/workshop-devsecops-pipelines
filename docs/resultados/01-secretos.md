---
title: "Resultado 1: Deteccion de Secretos"
description: Resultados esperados del escaneo de secretos con Gitleaks.
tags:
  - Resultados
  - Gitleaks
  - Secretos
---

# Stage 1 — Deteccion de Secretos (Gitleaks)

<div class="lab-meta">
  <div class="lab-meta-item">
    <strong>Herramienta</strong>
    Gitleaks v8
  </div>
  <div class="lab-meta-item">
    <strong>Artefacto</strong>
    gitleaks-report (SARIF)
  </div>
  <div class="lab-meta-item">
    <strong>Hallazgos esperados</strong>
    3 secretos filtrados
  </div>
</div>

---

## Que hace este stage

Gitleaks analiza **todo el historial de commits** (por eso usamos `fetch-depth: 0`) buscando patrones que coincidan con credenciales conocidas: claves AWS, tokens de API, client secrets de Azure, etc. Los hallazgos se exportan en formato SARIF y se suben tanto como artefacto descargable como a la pestana **Security** del repositorio.

---

## YAML del Workflow

```yaml
secrets-detection:
  name: '1. Deteccion de Secretos'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v5
      with:
        fetch-depth: 0

    - name: Gitleaks -- Escaneo de Secretos
      uses: gitleaks/gitleaks-action@v2
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        GITLEAKS_ENABLE_UPLOAD_ARTIFACT: false
        GITLEAKS_ENABLE_SUMMARY: true

    - name: Publicar reporte Gitleaks
      uses: actions/upload-artifact@v5
      if: always()
      with:
        name: gitleaks-report
        path: results.sarif
        retention-days: 30

    - name: Upload SARIF a GitHub Security
      uses: github/codeql-action/upload-sarif@v4
      if: always()
      with:
        sarif_file: results.sarif
        category: gitleaks
```

---

## Hallazgos esperados

| # | Archivo | Tipo de secreto | Linea | Regla Gitleaks |
|---|---------|-----------------|-------|----------------|
| 1 | `.env.example` | AWS Access Key ID | 3 | `aws-access-key-id` |
| 2 | `vulnerable-app/app/users.py` | Generic API Key | 8 | `generic-api-key` |
| 3 | `.env.example` | Azure Client Secret | 7 | `azure-client-secret` |

!!! warning "Salida tipica en el log del runner"

    ```
    Finding:     AKIAIOSFODNN7EXAMPLE
    Secret:      AKIAIOSFODNN7EXAMPLE
    RuleID:      aws-access-key-id
    Entropy:     3.52
    File:        .env.example
    Line:        3
    Fingerprint: .env.example:aws-access-key-id:3

    Finding:     supersecretapikey123
    Secret:      supersecretapikey123
    RuleID:      generic-api-key
    Entropy:     3.28
    File:        vulnerable-app/app/users.py
    Line:        8
    Fingerprint: vulnerable-app/app/users.py:generic-api-key:8

    12:45:02AM INF 3 commits scanned.
    12:45:02AM WRN leaks found: 3
    ```

---

## Donde verificar en GitHub

```mermaid
flowchart LR
    A[Tu repositorio] --> B["Security tab"]
    B --> C["Code scanning alerts"]
    C --> D["Filtrar: Tool = gitleaks"]
    style D fill:#046BD2,color:#fff
```

!!! tip "Que veras en la interfaz"

    1. Ve a **Security** > **Code scanning alerts**.
    2. Filtra por **Tool: gitleaks**.
    3. Veras **3 alertas** con severidad `Error`, cada una mostrando el archivo, la linea exacta y un snippet del secreto (parcialmente enmascarado).
    4. En **Actions** > click en el run > **Artifacts**, encontraras `gitleaks-report` como archivo `.sarif` descargable.
    5. En el **Job Summary** del step, Gitleaks muestra una tabla resumen con los hallazgos porque habilitamos `GITLEAKS_ENABLE_SUMMARY: true`.

---

## Flujo del stage

```mermaid
flowchart TD
    A["Checkout con historial completo<br/>fetch-depth: 0"] --> B["Gitleaks escanea commits"]
    B --> C{"Secretos encontrados?"}
    C -->|Si| D["Genera results.sarif"]
    C -->|No| E["Pipeline limpio"]
    D --> F["Upload artefacto<br/>gitleaks-report"]
    D --> G["Upload SARIF a<br/>GitHub Security"]
    style C fill:#e67700,color:#fff
    style D fill:#c92a2a,color:#fff
```

---

[:material-arrow-left: Volver al indice](index.md){ .md-button }
[:material-arrow-right: Siguiente: SAST (Semgrep)](02-sast.md){ .md-button .md-button--primary }
