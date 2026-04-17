---
tags:
  - lab
  - sca
  - trivy
  - sbom
---

# Lab 5 -- SCA y SBOM

<div class="lab-meta" markdown>
<div class="lab-meta-item" markdown>
<strong>Duracion</strong>
30 minutos
</div>
<div class="lab-meta-item" markdown>
<strong>Nivel</strong>
Principiante
</div>
<div class="lab-meta-item" markdown>
<strong>Herramientas</strong>
Trivy
</div>
<div class="lab-meta-item" markdown>
<strong>Resultado</strong>
Stage SCA con SBOM CycloneDX
</div>
</div>

!!! abstract "Objetivo"
    Usar Trivy en modo `fs` (filesystem) para analizar las dependencias de `vulnerable-app/`, detectar CVEs conocidas en los paquetes de `requirements.txt`, generar un SBOM (Software Bill of Materials) en formato CycloneDX e integrar todo en el pipeline.

## Que es SCA

El Analisis de Composicion de Software (**SCA**) examina las dependencias de terceros de una aplicacion para detectar:

- **Vulnerabilidades conocidas (CVEs)** en versiones especificas de librerias
- **Licencias** incompatibles o restringidas
- **Dependencias desactualizadas** con parches de seguridad disponibles

## Dependencias vulnerables en vulnerable-app/

El archivo `vulnerable-app/requirements.txt` contiene intencionalmente versiones antiguas con CVEs conocidas:

```text title="vulnerable-app/requirements.txt"
# VULNERABLE: Outdated versions with known CVEs
Flask==3.0.0
Jinja2==3.0.1
Werkzeug==2.0.1
requests==2.25.0
PyYAML==5.3.1
cryptography==3.3.2
gunicorn==20.1.0
```

| Paquete | Version | CVEs conocidas |
|---------|---------|---------------|
| **Flask** | 2.0.1 | Vulnerabilidades en manejo de cookies |
| **Jinja2** | 3.0.1 | CVE-2024-22195 (XSS en templates) |
| **Werkzeug** | 2.0.1 | CVE-2023-25577 (DoS), CVE-2023-23934 |
| **requests** | 2.25.0 | CVE-2023-32681 (header injection) |
| **PyYAML** | 5.3.1 | CVE-2020-14343 (arbitrary code execution) |
| **cryptography** | 3.3.2 | Multiples CVEs en OpenSSL bindings |

## Que es un SBOM

Un **Software Bill of Materials** (SBOM) es un inventario completo de todos los componentes de software usados en una aplicacion. Incluye:

- Nombre del paquete
- Version exacta
- Licencia
- Hash/checksum
- Relaciones de dependencias

Los formatos mas comunes son **CycloneDX** (OWASP) y **SPDX** (Linux Foundation).

## Pasos del laboratorio

<div class="steps" markdown>

1. **[Trivy FS y SBOM Local](step1.md)** -- Ejecutar `trivy fs` localmente contra `vulnerable-app/`, escanear `requirements.txt` para detectar CVEs y generar un SBOM en formato CycloneDX.

2. **[Añadir Job SCA](step2.md)** -- Implementar el job `sca` en `.github/workflows/devsecops.yml` con Trivy fs, configurar un gate de severidad y publicar el SBOM como artefacto del build.

</div>

## Prerequisitos

- Lab 4 completado (stage SAST funcionando)
- Docker instalado (para Trivy local y en pipeline)
