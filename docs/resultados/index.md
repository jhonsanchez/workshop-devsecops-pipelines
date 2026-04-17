---
title: Resultados del Pipeline
description: Qué produce cada stage del pipeline DevSecOps y qué deberías ver.
hide:
  - toc
tags:
  - Resultados
  - Pipeline
---

# Resultados del Pipeline

Cada stage del pipeline produce reportes, artefactos y hallazgos de seguridad.
Esta sección muestra los **resultados esperados** para que puedas verificar que
tu pipeline funcionó correctamente.

---

## Vista General

```mermaid
flowchart TD
    S1[1. Secretos<br/>Gitleaks] -->|SARIF + alertas| S2[2. SAST<br/>Semgrep]
    S2 -->|14 findings| S3[3. SCA<br/>Trivy FS]
    S3 -->|CVEs + SBOM| S4[4. Build<br/>Docker + GHCR]
    S4 -->|Imagen publicada| S5[5. Image Scan + Firma<br/>Trivy + Cosign]
    S5 -->|Firmada keyless| S6[6. IaC Scan<br/>Checkov]
    S6 -->|10 misconfigs| S7[7. Staging<br/>Docker Compose]
    S7 -->|App corriendo| S8[8. DAST<br/>OWASP ZAP]
    S8 -->|Alertas XSS, SQLi| S9[9. Producción<br/>Cosign verify]
    S9 -->|Firma OK| S10[10. Monitor<br/>Health + Smoke]

    style S1 fill:#046BD2,color:#fff
    style S2 fill:#046BD2,color:#fff
    style S3 fill:#046BD2,color:#fff
    style S4 fill:#046BD2,color:#fff
    style S5 fill:#046BD2,color:#fff
    style S6 fill:#046BD2,color:#fff
    style S7 fill:#046BD2,color:#fff
    style S8 fill:#046BD2,color:#fff
    style S9 fill:#046BD2,color:#fff
    style S10 fill:#046BD2,color:#fff
```

---

<div class="grid cards" markdown>

- :material-key-alert: **[1. Detección de Secretos](01-secretos.md)**

    Gitleaks encuentra credenciales en `.env.example` y `users.py`

- :material-shield-search: **[2. SAST — Semgrep](02-sast.md)**

    14 hallazgos: SQLi, XSS, MD5, debug mode, hardcoded secrets

- :material-package-variant-closed: **[3. SCA — Trivy FS](03-sca.md)**

    CVEs en dependencias + SBOM en formato CycloneDX

- :material-docker: **[4. Build + Imagen](04-build.md)**

    Imagen Docker publicada en GHCR con tags inmutables

- :material-certificate: **[5. Image Scan + Firma](05-image-scan.md)**

    Trivy escanea la imagen + Cosign firma keyless via Sigstore

- :material-terraform: **[6. IaC Scan](06-iac.md)**

    Checkov detecta 10 misconfigs en el Terraform inseguro

- :material-rocket-launch: **[7. Deploy Staging](07-staging.md)**

    App desplegada via Docker Compose, health check OK

- :material-web-check: **[8. DAST — OWASP ZAP](08-dast.md)**

    ZAP encuentra XSS, SQLi, cabeceras faltantes en la app en ejecución

- :material-shield-check: **[9. Deploy Producción](09-produccion.md)**

    Cosign verifica la firma antes de desplegar

- :material-chart-timeline-variant-shimmer: **[10. Monitorización](10-monitor.md)**

    Health checks, smoke tests y verificación de cabeceras

</div>

---

## Dónde Ver los Resultados

| Resultado | Dónde encontrarlo |
|---|---|
| Hallazgos de seguridad (SARIF) | **Security** → **Code scanning alerts** |
| Artefactos (reportes, SBOM) | **Actions** → click en el run → **Artifacts** |
| Imagen Docker | **Packages** (en la sidebar del repo) |
| Firma Cosign | `cosign verify` en la imagen publicada |
| Pipeline summary | **Actions** → click en el run → **Summary** |
