---
tags:
  - lab
  - azure-devops
  - setup
---

# Paso 2 -- Verificar el Pipeline

!!! abstract "Objetivo"
    Confirmar que el pipeline se ejecuta correctamente, entender la interfaz de Azure DevOps Pipelines y verificar que el trigger automatico funciona con cada push a `main`.

## 2.1 Inspeccionar la ejecucion del pipeline

Despues de crear el pipeline en el paso anterior, Azure DevOps deberia haber iniciado una ejecucion automatica. Navega a la interfaz:

1. Ve a **Pipelines** en el menu lateral
2. Haz clic en el pipeline que acabas de crear
3. Veras la lista de **Runs** (ejecuciones)

!!! info "Anatomia de una ejecucion"
    Cada ejecucion tiene:

    - **Run ID** -- Numero unico incremental
    - **Status** -- Queued, Running, Succeeded, Failed, Cancelled
    - **Branch** -- La rama que disparo la ejecucion
    - **Commit** -- El SHA del commit que la provoco
    - **Duration** -- Tiempo total de ejecucion

## 2.2 Explorar los logs

Haz clic en la ejecucion activa para ver el detalle:

1. Veras un diagrama de **stages** (por ahora solo "Hello World")
2. Haz clic en el stage **Hello World - Verificacion**
3. Veras los **jobs** dentro del stage
4. Haz clic en el job **Verificar conexion**
5. Aqui puedes ver cada **step** y sus logs:

Los logs deberian mostrar algo similar a:

```text title="Salida esperada del pipeline"
=========================================
  DevSecOps Pipeline - Workshop Entelgy
=========================================

Repositorio: mi-usuario/devsecops-workshop
Branch:      main
Commit:      a1b2c3d4e5f6...
Build ID:    42
Agent:       Hosted Agent

Pipeline conectado correctamente!
=========================================
```

Y la verificacion de estructura:

```text title="Salida - Verificar estructura del repo"
Verificando estructura del repositorio...

--- Contenido raiz ---
total 24
drwxr-xr-x  6 vsts vsts 4096 ... .
-rw-r--r--  1 vsts vsts  ... azure-pipelines.yml
drwxr-xr-x  5 vsts vsts 4096 ... vulnerable-app

--- Contenido de vulnerable-app/ ---
total 32
-rw-r--r--  1 vsts vsts  ... Dockerfile
-rw-r--r--  1 vsts vsts  ... Dockerfile.secure
-rw-r--r--  1 vsts vsts  ... app.py
-rw-r--r--  1 vsts vsts  ... docker-compose.yml
-rw-r--r--  1 vsts vsts  ... requirements.txt
drwxr-xr-x  5 vsts vsts 4096 ... src
```

!!! success "Paso Completado"
    Si ves los logs con la informacion del repositorio y la estructura de archivos de `vulnerable-app/`, tu pipeline esta correctamente conectado.

## 2.3 Entender la interfaz de Pipelines

Familiarizate con las secciones principales de la UI:

### Pagina de Runs

| Elemento | Descripcion |
|----------|-------------|
| **Recent runs** | Lista de las ultimas ejecuciones con su estado |
| **Branches** | Filtro para ver ejecuciones por rama |
| **Tags** | Filtro por tags de git |
| **Analytics** | Metricas de exito/fallo y duracion promedio |

### Detalle de un Run

| Seccion | Que muestra |
|---------|-------------|
| **Summary** | Vista general con stages, duracion y commit |
| **Jobs** | Lista de jobs con estado individual |
| **Logs** | Output paso a paso de cada step |
| **Tests** | Resultados de tests (lo usaremos mas adelante) |
| **Artifacts** | Artefactos publicados (SARIF, SBOM, etc.) |

!!! tip "Atajos utiles"
    - Haz clic en el **icono de reloj** en un step para ver su duracion exacta
    - Usa **Ctrl+F** en los logs para buscar texto
    - El boton **Re-run** permite re-ejecutar un pipeline con el mismo commit

## 2.4 Verificar el trigger automatico

Ahora vamos a comprobar que el pipeline se ejecuta automaticamente al hacer push:

1. Haz un cambio menor en el repositorio:

```bash title="Terminal"
# Agrega un comentario al pipeline
echo "" >> azure-pipelines.yml
echo "# Trigger test - $(date)" >> azure-pipelines.yml
git add azure-pipelines.yml
git commit -m "lab01: verificar trigger automatico"
git push origin main
```

2. Vuelve a Azure DevOps > **Pipelines**
3. Deberia aparecer una nueva ejecucion en estado **Queued** o **Running**

!!! warning "Si el trigger no funciona"
    Posibles causas:

    1. **Webhook no creado** -- Verifica en GitHub: Settings > Webhooks. Deberia haber un webhook de Azure DevOps.
    2. **Branch incorrecto** -- El trigger esta configurado para `main`. Si tu rama se llama `master`, cambia el YAML.
    3. **Service connection sin permisos** -- Revisa que la service connection tenga permiso `admin:repo_hook`.
    4. **Pipeline deshabilitado** -- En Azure DevOps, verifica que el pipeline no este en estado "Disabled".

## 2.5 Estructura de la UI para referencia futura

A lo largo del workshop, usaremos estas secciones constantemente:

```mermaid
graph TD
    A[Azure DevOps] --> B[Pipelines]
    B --> C[Runs - Historial]
    B --> D[Pipeline Editor - YAML]
    B --> E[Environments]
    B --> F[Library - Variable Groups]
    C --> G[Run Detail]
    G --> H[Logs]
    G --> I[Artifacts]
    G --> J[Tests]
```

!!! info "Que sigue"
    En el **Lab 2** reemplazaremos el stage "Hello World" por la estructura completa de 10 stages que formaran nuestro pipeline DevSecOps. Cada lab posterior rellenara uno de esos stages con herramientas reales de seguridad.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../step1/" class="md-button">Anterior: Paso 1</a>
  <a href="../../lab02-pipeline-base/" class="md-button md-button--primary">Siguiente: Lab 2</a>
</div>
