---
tags:
  - lab
  - gitleaks
  - secretos
  - seguridad
---

# Lab 3 -- Deteccion de Secretos

<div class="lab-meta" markdown>
<div class="lab-meta-item" markdown>
<strong>Duracion</strong>
45 minutos
</div>
<div class="lab-meta-item" markdown>
<strong>Nivel</strong>
Principiante
</div>
<div class="lab-meta-item" markdown>
<strong>Herramientas</strong>
Gitleaks
</div>
<div class="lab-meta-item" markdown>
<strong>Resultado</strong>
Stage SecretsDetection con SARIF
</div>
</div>

!!! abstract "Objetivo"
    Usar Gitleaks para detectar credenciales y secretos filtrados en el codigo fuente de `vulnerable-app/`, integrar la deteccion en el pipeline de Azure DevOps y practicar el flujo de remediacion.

## Por que es importante

Los secretos filtrados en repositorios son una de las causas mas frecuentes de brechas de seguridad. Segun GitHub, en 2023 se detectaron mas de **12.8 millones** de secretos expuestos en repositorios publicos. Un solo token de AWS, una clave de API o una contraseña de base de datos en el codigo puede comprometer toda la infraestructura.

## Que tiene vulnerable-app/

Nuestra aplicacion vulnerable contiene secretos **intencionalmente** plantados para propositos educativos:

| Archivo | Tipo de secreto | CWE |
|---------|-----------------|-----|
| `vulnerable-app/.env.example` | Credenciales AWS, Azure, Slack webhook | CWE-798 |
| `vulnerable-app/src/api/users.py` | API key hardcodeada, contraseña en codigo | CWE-798 |
| `vulnerable-app/Dockerfile` | Contraseña de BD en variable de entorno | CWE-798 |
| `vulnerable-app/app.py` | Secret key debil de Flask | CWE-330 |

## Pasos del laboratorio

<div class="steps" markdown>

1. **[Gitleaks Local](step1.md)** -- Instalar Gitleaks, escanear `vulnerable-app/` localmente e interpretar los hallazgos.

2. **[Añadir Stage al Pipeline](step2.md)** -- Implementar el stage `SecretsDetection` en `azure-pipelines.yml` usando Gitleaks en Docker, configurar para fallar si encuentra secretos y publicar el reporte SARIF.

3. **[Probar y Remediar](step3.md)** -- Plantar un secreto de prueba en una rama, ver como el pipeline lo detecta, y practicar la remediacion (revocar, rotar, reescribir historial).

</div>

## Prerequisitos

- Lab 2 completado (pipeline con 10 stages vacios)
- Docker instalado localmente (para ejecutar Gitleaks)
- Git instalado

!!! info "Gitleaks"
    [Gitleaks](https://github.com/gitleaks/gitleaks) es una herramienta open source para detectar secretos en repositorios Git. Analiza tanto el contenido actual como el historial de commits. Soporta reglas personalizadas y genera reportes en formato SARIF.
