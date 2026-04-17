---
tags:
  - lab
  - sast
  - semgrep
  - seguridad
---

# Lab 4 -- SAST con Semgrep

<div class="lab-meta" markdown>
<div class="lab-meta-item" markdown>
<strong>Duracion</strong>
45-60 minutos
</div>
<div class="lab-meta-item" markdown>
<strong>Nivel</strong>
Intermedio
</div>
<div class="lab-meta-item" markdown>
<strong>Herramientas</strong>
Semgrep
</div>
<div class="lab-meta-item" markdown>
<strong>Resultado</strong>
Stage SAST con reglas OWASP
</div>
</div>

!!! abstract "Objetivo"
    Utilizar Semgrep para realizar analisis estatico de seguridad (SAST) sobre el codigo de `vulnerable-app/`, detectar vulnerabilidades como SQL Injection, XSS y criptografia debil, integrar el analisis en el pipeline y configurar reglas personalizadas.

## Que es SAST

El Analisis Estatico de Seguridad de Aplicaciones (**SAST**) examina el codigo fuente **sin ejecutarlo** para encontrar patrones de vulnerabilidades. A diferencia de un linter que busca errores de estilo, SAST busca:

- Inyecciones (SQL, XSS, Command Injection)
- Uso inseguro de criptografia
- Credenciales hardcodeadas
- Configuraciones inseguras
- Violaciones de control de acceso

## Vulnerabilidades en vulnerable-app/

Nuestra aplicacion contiene vulnerabilidades intencionalmente plantadas:

| Archivo | Vulnerabilidad | CWE | OWASP Top 10 |
|---------|---------------|-----|---------------|
| `src/auth/login.py` | SQL Injection en login y registro | CWE-89 | A03:2021 Injection |
| `src/views/search.py` | Reflected XSS via `render_template_string` | CWE-79 | A03:2021 Injection |
| `src/api/users.py` | Hardcoded API key y password | CWE-798 | A07:2021 Identification Failures |
| `src/api/users.py` | Broken access control (no auth) | CWE-285 | A01:2021 Broken Access Control |
| `src/utils/crypto.py` | MD5 para passwords (sin salt) | CWE-327 | A02:2021 Crypto Failures |
| `src/utils/crypto.py` | Base64 como "cifrado" | CWE-326 | A02:2021 Crypto Failures |
| `app.py` | Debug mode en produccion | CWE-489 | A05:2021 Security Misconfiguration |
| `app.py` | Secret key debil | CWE-330 | A02:2021 Crypto Failures |

## Pasos del laboratorio

<div class="steps" markdown>

1. **[Semgrep Local](step1.md)** -- Instalar Semgrep, ejecutar contra `vulnerable-app/`, encontrar SQLi, XSS, secretos y criptografia debil. Mapear hallazgos a CWEs y OWASP Top 10.

2. **[Añadir Job SAST](step2.md)** -- Implementar el job `sast` en `.github/workflows/devsecops.yml` con Semgrep en Docker. Configurar rulesets `p/owasp-top-ten` y `p/secrets`. Publicar SARIF.

3. **[Reglas Personalizadas](step3.md)** -- Usar la regla personalizada de `vulnerable-app/.semgrep/rules/entelgy.yml`. Configurar umbrales de severidad. Probar con una vulnerabilidad intencional.

</div>

## Prerequisitos

- Lab 3 completado (stage SecretsDetection funcionando)
- Python 3.8+ instalado (para Semgrep local)
- Docker instalado

!!! info "Semgrep"
    [Semgrep](https://semgrep.dev) es una herramienta SAST open source que soporta 30+ lenguajes. Usa patrones similares al codigo fuente (no regex) para encontrar vulnerabilidades, lo que la hace mas precisa y facil de personalizar que herramientas basadas en regex.
