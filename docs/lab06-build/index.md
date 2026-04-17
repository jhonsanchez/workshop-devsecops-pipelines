---
tags:
  - lab
  - docker
  - acr
  - build
  - hadolint
---

# Lab 6 -- Build e Imagen

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
Docker, Hadolint, ACR
</div>
<div class="lab-meta-item" markdown>
<strong>Resultado</strong>
Imagen Docker segura en ACR
</div>
</div>

!!! abstract "Objetivo"
    Revisar y mejorar el Dockerfile inseguro de `vulnerable-app/`, ejecutar Hadolint para detectar malas practicas, construir la imagen Docker usando el Dockerfile seguro, e integrar el proceso de build en el pipeline con push a Azure Container Registry (ACR).

## Por que importa la seguridad del Dockerfile

Un Dockerfile inseguro puede introducir vulnerabilidades que afectan a toda la cadena:

- **Ejecutar como root** -- Un atacante que comprometa la app tiene privilegios de root
- **Imagen base sin pinear** -- `python:latest` puede cambiar y romper o introducir vulnerabilidades
- **Secretos en ENV** -- Quedan permanentemente en las capas de la imagen
- **Herramientas innecesarias** -- `curl`, `vim`, `netcat` dan al atacante mas superficie de ataque
- **Puertos innecesarios** -- Exponer SSH en un contenedor no tiene sentido

## Dockerfiles en vulnerable-app/

Nuestra aplicacion tiene dos Dockerfiles:

| Archivo | Proposito |
|---------|----------|
| `vulnerable-app/Dockerfile` | Version **insegura** (para analizar) |
| `vulnerable-app/Dockerfile.secure` | Version **segura** (referencia) |

## Pasos del laboratorio

<div class="steps" markdown>

1. **[Hardening del Dockerfile](step1.md)** -- Revisar el Dockerfile inseguro, ejecutar Hadolint para detectar problemas, y corregirlos usando `Dockerfile.secure` como referencia. Construir la imagen localmente.

2. **[Stage de Build + ACR](step2.md)** -- Implementar el stage `Build` en `azure-pipelines.yml` usando la tarea `Docker@2`. Construir la imagen, tagearla con `$(Build.BuildId)` y el SHA del commit, y publicarla en ACR.

3. **[Inmutabilidad en ACR](step3.md)** -- Verificar la imagen en ACR, inspeccionar las capas y configurar una politica de inmutabilidad de tags.

</div>

## Prerequisitos

- Lab 5 completado (stage SCA funcionando)
- Docker instalado localmente
- (Opcional) Azure Container Registry creado

!!! info "Azure Container Registry"
    Si no tienes un ACR disponible, puedes simular el paso de push usando Docker Hub o un registro local. Los conceptos de build y tagging son identicos.
