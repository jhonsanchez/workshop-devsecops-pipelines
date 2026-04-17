---
title: Configuración del Entorno
description: Fork el repositorio, valida dependencias y ejecuta el pipeline.
tags:
  - Setup
  - GitHub Actions
---

# Configuración del Entorno

Sigue estos pasos para tener el pipeline DevSecOps funcionando en tu cuenta de GitHub.

<div class="lab-meta">
  <div class="lab-meta-item">
    <strong>Tiempo</strong>
    15–20 min
  </div>
  <div class="lab-meta-item">
    <strong>Requisitos</strong>
    Cuenta GitHub
  </div>
  <div class="lab-meta-item">
    <strong>Resultado</strong>
    Pipeline 10/10 verde
  </div>
</div>

---

## Paso 1: Fork del Repositorio

1. Ve a [github.com/jhonsanchez/workshop-devsecops-pipelines](https://github.com/jhonsanchez/workshop-devsecops-pipelines)
2. Haz clic en **Fork** (esquina superior derecha)
3. Selecciona tu cuenta como destino
4. **Importante:** desmarca "Copy the `main` branch only" — necesitas la rama `gha`
5. Haz clic en **Create fork**

!!! tip "Verifica el fork"
    Tu fork debería estar en `github.com/<TU-USUARIO>/workshop-devsecops-pipelines`
    con la rama `gha` disponible.

---

## Paso 2: Clonar y Cambiar a la Rama `gha`

```bash
git clone https://github.com/<TU-USUARIO>/workshop-devsecops-pipelines.git
cd workshop-devsecops-pipelines
git checkout gha
```

---

## Paso 3: Validar Dependencias Locales

Ejecuta el script de validación para verificar que tienes todo lo necesario:

```bash
./validate.sh
```

Salida esperada:

```
═══════════════════════════════════════════════
  DevSecOps Workshop — Validación de Entorno
═══════════════════════════════════════════════

[✓] Git           — 2.44.0
[✓] Docker        — 27.1.1
[✓] Python        — 3.11.9
[✓] pip           — 24.0
[✓] GitHub CLI    — 2.52.0

═══════════════════════════════════════════════
  5/5 dependencias OK — Entorno listo
═══════════════════════════════════════════════
```

!!! warning "¿Falta algo?"
    Si alguna dependencia falla, instálala:

    | Herramienta | Instalación |
    |---|---|
    | Git | `brew install git` / `apt install git` |
    | Docker | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) |
    | Python 3 | `brew install python@3.11` / `apt install python3` |
    | GitHub CLI | `brew install gh` / [cli.github.com](https://cli.github.com/) |

---

## Paso 4: Habilitar GitHub Actions

1. Ve a tu fork en GitHub
2. Haz clic en la pestaña **Actions**
3. Si aparece un banner diciendo "Workflows aren't being run", haz clic en **I understand my workflows, go ahead and enable them**

---

## Paso 5: Configurar Environments (Opcional)

Para que los jobs de Deploy pidan aprobación:

1. Ve a **Settings** → **Environments**
2. Crea el environment `staging`
3. Crea el environment `production`
4. En `production`, añade un **Required reviewer** (tu propio usuario)

!!! info "Sin environments"
    Si no configuras environments, los jobs de deploy se ejecutan
    automáticamente sin esperar aprobación. El pipeline funciona igual.

---

## Paso 6: Push a Main → Pipeline se Ejecuta

```bash
# Merge gha into main (o simplemente push a gha)
git push origin gha
```

O si quieres disparar en `main`:

```bash
git checkout main
git merge gha
git push origin main
```

Ahora ve a **Actions** → deberías ver el pipeline **DevSecOps Pipeline** ejecutándose.

---

## Paso 7: Verificar que Todo Está Verde

El pipeline tarda ~5 minutos. Cuando termine deberías ver:

```
✓ 1. Detección de Secretos      (~15s)
✓ 2. Análisis Estático (SAST)   (~30s)
✓ 3. Análisis de Composición    (~25s)
✓ 4. Build + Imagen             (~30s)
✓ 5. Escaneo de Imagen + Firma  (~25s)
✓ 6. Escaneo de IaC             (~25s)
✓ 7. Deploy a Staging           (~30s)
✓ 8. Análisis Dinámico (DAST)   (~2min)
✓ 9. Deploy a Producción        (~10s)
✓ 10. Verificación Post-Deploy  (~25s)
```

!!! success "¡Pipeline completo!"
    Si ves 10 checks verdes, tu entorno está listo. Ve a la sección
    [Resultados](../resultados/index.md) para entender qué hizo cada stage.

---

## Troubleshooting

??? question "El pipeline no se ejecuta"
    - Verifica que GitHub Actions está habilitado (Paso 4)
    - Verifica que estás en la rama correcta (`gha` o `main`)
    - Ve a **Actions** → **DevSecOps Pipeline** → **Run workflow** (manual)

??? question "Job de Build falla"
    - Verifica que los packages (GHCR) están habilitados en tu repo
    - Ve a **Settings** → **Actions** → **General** → **Workflow permissions** → selecciona **Read and write permissions**

??? question "Job de Deploy pide aprobación y no avanza"
    - Ve a **Actions** → haz clic en el run → **Review deployments** → aprueba

??? question "El script validate.sh no ejecuta"
    ```bash
    chmod +x validate.sh
    ./validate.sh
    ```

---

[Ver Resultados del Pipeline :octicons-arrow-right-24:](../resultados/index.md){ .md-button .md-button--primary }
