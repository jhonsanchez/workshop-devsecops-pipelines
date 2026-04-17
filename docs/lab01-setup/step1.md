---
tags:
  - lab
  - azure-devops
  - setup
---

# Paso 1 -- Crear Proyecto y Conectar Repo

!!! abstract "Objetivo"
    Crear una organizacion y proyecto en Azure DevOps, configurar una service connection a GitHub y crear el archivo `azure-pipelines.yml` con un stage inicial de verificacion.

## 1.1 Crear la organizacion en Azure DevOps

Si aun no tienes una organizacion de Azure DevOps, creala ahora:

1. Navega a [https://dev.azure.com](https://dev.azure.com)
2. Inicia sesion con tu cuenta de Microsoft
3. Haz clic en **New organization**
4. Elige un nombre para tu organizacion (por ejemplo: `mi-empresa-devsecops`)
5. Selecciona la region mas cercana

!!! tip "Organizacion gratuita"
    Azure DevOps ofrece un tier gratuito que incluye 1 pipeline paralelo con 1,800 minutos/mes para proyectos publicos y hasta 5 usuarios. Es suficiente para este workshop.

## 1.2 Crear el proyecto

Dentro de tu organizacion:

1. Haz clic en **+ New Project**
2. Configura los siguientes valores:

    | Campo | Valor |
    |-------|-------|
    | **Project name** | `devsecops-workshop` |
    | **Description** | Pipeline DevSecOps incremental |
    | **Visibility** | Private |
    | **Version control** | Git |
    | **Work item process** | Basic |

3. Haz clic en **Create**

!!! success "Paso Completado"
    Deberias ver el dashboard del proyecto `devsecops-workshop` en Azure DevOps.

## 1.3 Crear Service Connection a GitHub

Necesitamos conectar Azure DevOps con el repositorio de GitHub donde esta el codigo:

1. En el proyecto, ve a **Project Settings** (icono de engranaje, esquina inferior izquierda)
2. En el menu lateral, busca **Service connections** bajo la seccion "Pipelines"
3. Haz clic en **New service connection**
4. Selecciona **GitHub**
5. Elige el metodo de autenticacion:

    === "OAuth (Recomendado)"

        1. Selecciona **AzurePipelines** como configuracion OAuth
        2. Haz clic en **Authorize**
        3. Concede acceso al repositorio en la ventana emergente de GitHub

    === "Personal Access Token"

        1. En GitHub, ve a **Settings > Developer settings > Personal Access Tokens > Tokens (classic)**
        2. Genera un nuevo token con los scopes: `repo`, `admin:repo_hook`
        3. Copia el token y pegalo en Azure DevOps

6. Nombra la connection: `github-connection`
7. Marca **Grant access permission to all pipelines**
8. Haz clic en **Save**

!!! warning "Permisos del token"
    Si usas un Personal Access Token, asegurate de que tiene permiso `admin:repo_hook` para que Azure DevOps pueda crear webhooks automaticamente. Sin esto, los triggers no funcionaran.

## 1.4 Crear el archivo azure-pipelines.yml

Ahora vamos a crear el archivo de definicion del pipeline en el repositorio. Crea el archivo `azure-pipelines.yml` en la **raiz** del repositorio:

```yaml title="azure-pipelines.yml"
# DevSecOps Pipeline — Workshop Entelgy
# Lab 1: Pipeline inicial de verificacion

trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

stages:
  - stage: HelloWorld
    displayName: 'Hello World - Verificacion'
    jobs:
      - job: Verify
        displayName: 'Verificar conexion'
        steps:
          - checkout: self
            displayName: 'Checkout del repositorio'

          - script: |
              echo "========================================="
              echo "  DevSecOps Pipeline - Workshop Entelgy"
              echo "========================================="
              echo ""
              echo "Repositorio: $(Build.Repository.Name)"
              echo "Branch:      $(Build.SourceBranchName)"
              echo "Commit:      $(Build.SourceVersion)"
              echo "Build ID:    $(Build.BuildId)"
              echo "Agent:       $(Agent.MachineName)"
              echo ""
              echo "Pipeline conectado correctamente!"
              echo "========================================="
            displayName: 'Info del Pipeline'

          - script: |
              echo "Verificando estructura del repositorio..."
              echo ""
              echo "--- Contenido raiz ---"
              ls -la
              echo ""
              echo "--- Contenido de vulnerable-app/ ---"
              ls -la vulnerable-app/
              echo ""
              echo "--- Dockerfile encontrado ---"
              cat vulnerable-app/Dockerfile
            displayName: 'Verificar estructura del repo'
```

!!! tip "Donde crear el archivo"
    El archivo `azure-pipelines.yml` debe estar en la **raiz** del repositorio, no dentro de `vulnerable-app/`. Azure DevOps buscara este archivo por defecto al crear un pipeline YAML.

## 1.5 Hacer push del archivo

Sube el archivo al repositorio:

```bash title="Terminal"
git add azure-pipelines.yml
git commit -m "lab01: agregar pipeline inicial de verificacion"
git push origin main
```

## 1.6 Crear el pipeline en Azure DevOps

1. En Azure DevOps, ve a **Pipelines** en el menu lateral
2. Haz clic en **New Pipeline**
3. Selecciona **GitHub** como origen del codigo
4. Busca y selecciona tu repositorio
5. Azure DevOps detectara automaticamente el archivo `azure-pipelines.yml`
6. Revisa el contenido del YAML y haz clic en **Run**

!!! success "Paso Completado"
    El pipeline deberia iniciar su primera ejecucion. En el siguiente paso verificaremos los resultados y exploraremos la interfaz de Azure DevOps.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../" class="md-button">Volver al Lab 1</a>
  <a href="../step2/" class="md-button md-button--primary">Paso 2: Verificar el Pipeline</a>
</div>
