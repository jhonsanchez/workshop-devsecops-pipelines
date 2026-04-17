---
tags:
  - lab
  - github-actions
  - setup
---

# Paso 1 -- Crear Workflow y Configurar Repo

!!! abstract "Objetivo"
    Configurar GitHub Actions en el repositorio y crear el archivo `.github/workflows/devsecops.yml` con un job inicial de verificacion.

## 1.1 Verificar el repositorio en GitHub

Asegurate de que tu repositorio esta listo:

1. Navega a [https://github.com](https://github.com)
2. Inicia sesion con tu cuenta de GitHub
3. Verifica que tienes el repositorio `devsecops-workshop` con la carpeta `vulnerable-app/`

!!! tip "GitHub Actions gratuito"
    GitHub Actions ofrece 2,000 minutos/mes gratuitos para repositorios privados y minutos ilimitados para repositorios publicos. Es suficiente para este workshop.

## 1.2 Configurar el repositorio

En tu repositorio:

1. Ve a **Settings** > **Actions** > **General**
2. Verifica que **Actions permissions** esta configurado para permitir acciones:

    | Campo | Valor |
    |-------|-------|
    | **Actions permissions** | Allow all actions and reusable workflows |
    | **Workflow permissions** | Read and write permissions |

3. Haz clic en **Save**

!!! success "Paso Completado"
    Deberias ver la configuracion de Actions habilitada en tu repositorio.

## 1.3 Configurar Secretos del repositorio

GitHub Actions usa **Secrets** para gestionar credenciales de forma segura:

1. En el repositorio, ve a **Settings** > **Secrets and variables** > **Actions**
2. Aqui puedes agregar secretos que se usaran en los labs posteriores
3. Por ahora, no necesitas crear ningun secreto

!!! info "Secretos en GitHub Actions"
    Los secretos se inyectan como variables de entorno en los workflows. Se enmascaran automaticamente en los logs. Los configuraremos en labs posteriores cuando sean necesarios.

## 1.4 Crear el archivo .github/workflows/devsecops.yml

Ahora vamos a crear el archivo de definicion del workflow en el repositorio. Crea la estructura de directorios `.github/workflows/` y el archivo `devsecops.yml`:

```yaml title=".github/workflows/devsecops.yml"
# DevSecOps Workflow — Workshop Entelgy
# Lab 1: Workflow inicial de verificacion

name: DevSecOps Pipeline

on:
  push:
    branches:
      - main

jobs:
  hello-world:
    name: 'Hello World - Verificacion'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        name: 'Checkout del repositorio'

      - run: |
          echo "========================================="
          echo "  DevSecOps Pipeline - Workshop Entelgy"
          echo "========================================="
          echo ""
          echo "Repositorio: ${{ github.repository }}"
          echo "Branch:      ${{ github.ref_name }}"
          echo "Commit:      ${{ github.sha }}"
          echo "Run Number:  ${{ github.run_number }}"
          echo "Runner:      ${{ runner.name }}"
          echo ""
          echo "Workflow conectado correctamente!"
          echo "========================================="
        name: 'Info del Workflow'

      - run: |
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
        name: 'Verificar estructura del repo'
```

!!! tip "Donde crear el archivo"
    El archivo debe estar en `.github/workflows/devsecops.yml` dentro del repositorio. GitHub Actions detecta automaticamente los archivos YAML en esta carpeta.

## 1.5 Hacer push del archivo

Sube el archivo al repositorio:

```bash title="Terminal"
mkdir -p .github/workflows
git add .github/workflows/devsecops.yml
git commit -m "lab01: agregar workflow inicial de verificacion"
git push origin main
```

## 1.6 Verificar el workflow en GitHub

1. En GitHub, ve a la pestana **Actions** de tu repositorio
2. GitHub Actions detectara automaticamente el archivo `.github/workflows/devsecops.yml`
3. Deberia aparecer el workflow **DevSecOps Pipeline** en la lista
4. El push a `main` habra disparado la primera ejecucion automaticamente

!!! success "Paso Completado"
    El workflow deberia iniciar su primera ejecucion. En el siguiente paso verificaremos los resultados y exploraremos la interfaz de GitHub Actions.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../" class="md-button">Volver al Lab 1</a>
  <a href="../step2/" class="md-button md-button--primary">Paso 2: Verificar el Pipeline</a>
</div>
