---
title: "Limpieza de Recursos"
description: Guía para eliminar todos los recursos creados durante el workshop — GitHub Actions, ACR, Azure, Docker e imágenes locales
tags:
  - limpieza
  - cleanup
  - azure
  - terraform
  - docker
---

# Limpieza de Recursos

<div class="lab-meta">
  <div class="lab-meta-item">
    <strong>Duración estimada</strong>
    15 minutos
  </div>
  <div class="lab-meta-item">
    <strong>Importancia</strong>
    Evitar costes innecesarios
  </div>
</div>

---

!!! warning "Importante: evita costes no deseados"
    Los recursos de Azure creados durante el workshop generan costes. Sigue esta guía para eliminar **todos** los recursos una vez finalizado el workshop. No dejes recursos activos si no los vas a utilizar.

---

## 1. Recursos de Azure (Terraform)

Si utilizaste Terraform para crear la infraestructura, la forma más limpia de eliminar todo es con `terraform destroy`.

### Destruir infraestructura con Terraform

```bash
# Navegar al directorio de infraestructura
cd infrastructure/

# Verificar qué se va a destruir (dry-run)
terraform plan -destroy

# Revisar la lista de recursos a destruir
# Confirmar que son los recursos del workshop

# Ejecutar la destrucción
terraform destroy
```

!!! danger "Verifica antes de destruir"
    `terraform destroy` eliminará **todos** los recursos gestionados por el state file. Revisa el plan antes de confirmar. Si compartes la suscripción de Azure con otros proyectos, verifica que solo estás destruyendo los recursos del workshop.

### Verificar que no quedan recursos

```bash
# Listar resource groups del workshop
az group list --query "[?starts_with(name, 'rg-devsecops')].name" -o tsv

# Si algún resource group sigue existiendo, eliminarlo manualmente
az group delete --name rg-devsecops-workshop --yes --no-wait

# Verificar que no hay recursos huérfanos
az resource list --query "[?tags.project=='devsecops-workshop']" -o table
```

---

## 2. Azure Container Registry (ACR)

Si el ACR fue creado con Terraform, ya se eliminó en el paso anterior. Si lo creaste manualmente:

```bash
# Listar registros de contenedores
az acr list --query "[?starts_with(name, 'acrdevsecops')].name" -o tsv

# Eliminar el ACR
az acr delete --name acrdevsecopsworkshop --yes

# Verificar eliminación
az acr list --output table
```

### Eliminar imágenes del ACR (si no eliminas el ACR completo)

```bash
# Listar repositorios
az acr repository list --name acrdevsecopsworkshop -o tsv

# Eliminar un repositorio específico y todas sus tags
az acr repository delete --name acrdevsecopsworkshop --repository devsecops-app --yes

# Eliminar imágenes sin tag (dangling)
az acr run --cmd "acr purge --filter 'devsecops-app:.*' --ago 0d --untagged" \
  --registry acrdevsecopsworkshop /dev/null
```

---

## 3. GitHub Actions

### Eliminar el proyecto de GitHub Actions

!!! info "Opcional"
    Si quieres conservar el proyecto como referencia, puedes dejarlo. Los proyectos de GitHub Actions no generan costes de Azure (salvo si tienes agentes self-hosted).

```bash
# Listar proyectos en la organización
az devops project list --organization https://dev.azure.com/tu-organizacion -o table

# Eliminar el proyecto del workshop
az devops project delete \
  --id <project-id> \
  --organization https://dev.azure.com/tu-organizacion \
  --yes
```

### Eliminar GitHub Secrets (o GitHub Secrets)

Si no eliminas el proyecto, al menos elimina las GitHub Secrets (o GitHub Secrets) que tienen credenciales:

1. Ve a **Project Settings** > **Service connections**
2. Elimina credenciales externas de GitHub Secrets
3. Elimina cualquier conexión a Docker Registry

### Revisar GitHub Environments

1. Ve a **Pipelines** > **Library**
2. Elimina los GitHub Environments que contengan secretos del workshop

---

## 4. Imágenes Docker Locales

Las imágenes de Docker que construiste y descargaste durante el workshop ocupan espacio en disco.

```bash
# Listar imágenes relacionadas con el workshop
docker images | grep -E "devsecops|workshop|semgrep|trivy|zaproxy|cosign"

# Eliminar imágenes del workshop por nombre
docker rmi $(docker images --filter "reference=*devsecops*" -q) 2>/dev/null
docker rmi $(docker images --filter "reference=*workshop*" -q) 2>/dev/null

# Eliminar imágenes de herramientas usadas en los labs
docker rmi ghcr.io/zaproxy/zaproxy:stable 2>/dev/null
docker rmi semgrep/semgrep:latest 2>/dev/null
docker rmi aquasec/trivy:latest 2>/dev/null
docker rmi gcr.io/projectsigstore/cosign:latest 2>/dev/null

# Eliminar imágenes dangling (sin tag)
docker image prune -f

# Limpieza más agresiva: eliminar todo lo no utilizado
# (imágenes, contenedores parados, redes, build cache)
docker system prune -a -f
```

!!! warning "docker system prune -a"
    El comando `docker system prune -a` elimina **todas** las imágenes no utilizadas por contenedores en ejecución, no solo las del workshop. Usa este comando solo si estás seguro de que no necesitas otras imágenes locales.

### Verificar espacio recuperado

```bash
# Ver espacio usado por Docker antes de limpiar
docker system df

# Después de limpiar
docker system df
```

---

## 5. Entorno Virtual de Python (venv)

Si creaste un entorno virtual para las herramientas del workshop:

```bash
# Desactivar el entorno virtual (si está activo)
deactivate 2>/dev/null

# Eliminar el directorio del entorno virtual
rm -rf ~/devsecops-workshop-venv
# o donde hayas creado el venv:
rm -rf .venv

# Verificar que se eliminó
ls -la ~/devsecops-workshop-venv 2>/dev/null || echo "venv eliminado correctamente"
```

### Desinstalar herramientas Python globales (opcional)

Si instalaste herramientas globalmente con pip y no las necesitas:

```bash
pip uninstall checkov semgrep gitleaks detect-secrets -y
```

---

## 6. Archivos Locales del Workshop

```bash
# Eliminar el directorio del repositorio clonado
rm -rf ~/projects/devsecops-workshop
# o donde hayas clonado el repo

# Eliminar reportes generados durante los labs
rm -rf /tmp/devsecops-reports

# Eliminar claves de Cosign generadas (si usaste modo con clave)
rm -f cosign.key cosign.pub
```

!!! tip "Si quieres conservar los reportes"
    Antes de eliminar, puedes copiar los reportes SARIF y HTML generados durante los labs a un directorio de respaldo. Son útiles como referencia.

---

## 7. Configuración de Git (Hooks)

Si configuraste pre-commit hooks durante el Lab 3:

```bash
# Eliminar pre-commit hooks del repositorio
rm -f .git/hooks/pre-commit

# Si usaste el framework pre-commit
pre-commit uninstall
pre-commit clean
```

---

## 8. Credenciales y Tokens

!!! danger "Paso crítico de seguridad"
    Revoca cualquier token o credencial que hayas creado durante el workshop.

| Credencial | Dónde revocar |
|---|---|
| Azure Service Principal secret | Azure Portal > Entra ID > App registrations > Certificates & secrets |
| GitHub Actions PAT | GitHub Actions > User Settings > Personal Access Tokens |
| Cosign key pair | Eliminar archivos `cosign.key` y `cosign.pub` locales |
| Docker Hub token | Docker Hub > Account Settings > Security |
| GitHub PAT (si se creó) | GitHub > Settings > Developer Settings > Personal Access Tokens |

```bash
# Revocar el service principal de Azure (si fue creado manualmente)
az ad app delete --id <app-id>

# Verificar que no quedan service principals del workshop
az ad sp list --display-name "devsecops-workshop" -o table
```

---

## Checklist de Verificación Final

Ejecuta estas comprobaciones para confirmar que la limpieza fue completa:

```bash
echo "=== Verificación de limpieza ==="

echo ""
echo "1. Resource Groups de Azure:"
az group list --query "[?starts_with(name, 'rg-devsecops')]" -o table 2>/dev/null || echo "   (Azure CLI no configurado o no hay resource groups)"

echo ""
echo "2. Azure Container Registry:"
az acr list --query "[?starts_with(name, 'acrdevsecops')]" -o table 2>/dev/null || echo "   (No hay ACRs del workshop)"

echo ""
echo "3. Imágenes Docker locales del workshop:"
docker images | grep -E "devsecops|workshop" || echo "   No hay imágenes del workshop"

echo ""
echo "4. Entorno virtual Python:"
ls -d ~/devsecops-workshop-venv 2>/dev/null && echo "   ⚠️  venv existe todavía" || echo "   venv eliminado"

echo ""
echo "5. Claves Cosign:"
ls cosign.key 2>/dev/null && echo "   ⚠️  cosign.key existe todavía" || echo "   No hay claves Cosign"

echo ""
echo "6. Service Principals de Azure:"
az ad sp list --display-name "devsecops-workshop" --query "[].displayName" -o tsv 2>/dev/null || echo "   (No hay SPs del workshop)"

echo ""
echo "=== Verificación completada ==="
```

### Estado esperado tras la limpieza

| Recurso | Estado esperado |
|---|---|
| Resource Groups de Azure | Eliminados |
| Azure Container Registry | Eliminado |
| GitHub Actions Project | Eliminado o conservado sin GitHub Secrets (o GitHub Secrets) |
| Imágenes Docker locales | Eliminadas |
| Entorno virtual Python | Eliminado |
| Pre-commit hooks | Eliminados |
| Claves Cosign | Eliminadas |
| Service Principals / PATs | Revocados |
| Reportes de escaneo | Eliminados o respaldados |

---

!!! success "Limpieza completada"
    Si todos los checks anteriores muestran el estado esperado, la limpieza del workshop se ha completado correctamente. No deberías ver cargos adicionales en tu suscripción de Azure relacionados con el workshop.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="../cierre/" class="md-button">:material-arrow-left: Cierre del Workshop</a>
  <a href="../" class="md-button md-button--primary">Volver al inicio :material-home:</a>
</div>
