---
tags:
  - lab
  - checkov
  - terraform
  - iac
---

# Paso 1 -- Checkov Local

!!! abstract "Objetivo"
    Instalar Checkov localmente, escanear los archivos Terraform en `vulnerable-app/infrastructure/main.tf`, y analizar los hallazgos de seguridad: acceso publico en storage, NSG abierto, admin habilitado en ACR, y HTTPS no forzado.

## Contexto

Checkov es un escaner estatico de IaC que soporta Terraform, CloudFormation, Kubernetes, Dockerfile, y mas. Tiene mas de 1000 reglas integradas para AWS, Azure y GCP. Analiza los archivos sin necesidad de credenciales cloud ni ejecucion de `terraform plan`.

## 1.1 Instalar Checkov

```bash title="Instalar Checkov"
# Opcion 1: pip (recomendado)
pip install checkov

# Opcion 2: pip con entorno virtual
python3 -m venv venv
source venv/bin/activate
pip install checkov

# Verificar instalacion
checkov --version
```

!!! tip "Alternativa: Docker"
    Si prefieres no instalar con pip, puedes usar Docker:
    ```bash
    docker run --rm -v $(pwd):/tf bridgecrew/checkov -d /tf
    ```

## 1.2 Revisar el Terraform vulnerable

Antes de escanear, revisemos que tiene `vulnerable-app/infrastructure/main.tf`:

```hcl title="vulnerable-app/infrastructure/main.tf (fragmentos clave)"
# VULNERABLE: Storage account con acceso publico
resource "azurerm_storage_account" "data" {
  name                     = "entelgyworkshopdata"
  # ...
  allow_nested_items_to_be_public = true    # Acceso publico a blobs
  enable_https_traffic_only       = false   # HTTPS no forzado
}

# VULNERABLE: Container registry con admin habilitado
resource "azurerm_container_registry" "acr" {
  name          = "entelgyworkshopacr"
  # ...
  admin_enabled = true  # Credenciales admin expuestas
}

# VULNERABLE: Web App sin HTTPS
resource "azurerm_linux_web_app" "app" {
  # ...
  https_only = false  # Permite HTTP sin cifrar
}

# VULNERABLE: NSG con SSH abierto al mundo
resource "azurerm_network_security_group" "nsg" {
  security_rule {
    name                   = "AllowSSH"
    source_address_prefix  = "*"  # 0.0.0.0/0
    destination_port_range = "22"
  }
  security_rule {
    name                   = "AllowAll"
    source_address_prefix  = "*"
    destination_port_range = "*"  # TODOS los puertos abiertos
  }
}
```

## 1.3 Ejecutar Checkov

```bash title="Escanear Terraform con Checkov"
cd vulnerable-app/

# Escaneo basico
checkov -d infrastructure/

# Escaneo con formato especifico
checkov -d infrastructure/ --output cli

# Escaneo solo de Terraform
checkov -d infrastructure/ --framework terraform
```

## 1.4 Salida esperada de Checkov

Checkov producira una salida similar a esta:

```text title="Salida de Checkov (esperada)"
       _               _
   ___| |__   ___  ___| | _______   __
  / __| '_ \ / _ \/ __| |/ / _ \ \ / /
 | (__| | | |  __/ (__|   < (_) \ V /
  \___|_| |_|\___|\___|_|\_\___/ \_/

By Prisma Cloud | version: 3.2.x

terraform scan results:

Passed checks: 2
Failed checks: 12
Skipped checks: 0

Check: CKV_AZURE_35: "Ensure default network access rule for Storage Accounts is set to deny"
        FAILED for resource: azurerm_storage_account.data
        File: /main.tf:17-31
        Guide: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/azure-policies/azure-networking-policies/set-default-network-access-rule-for-storage-accounts-to-deny

Check: CKV_AZURE_3: "Ensure that 'Secure transfer required' is set to 'Enabled'"
        FAILED for resource: azurerm_storage_account.data
        File: /main.tf:17-31
        Guide: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/azure-policies/azure-storage-policies/ensure-secure-transfer-required-is-enabled

Check: CKV_AZURE_137: "Ensure ACR admin account is disabled"
        FAILED for resource: azurerm_container_registry.acr
        File: /main.tf:39-45
        Guide: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/azure-policies/azure-general-policies/azr-general-137

Check: CKV_AZURE_14: "Ensure web app redirects all HTTP traffic to HTTPS in Azure App Service"
        FAILED for resource: azurerm_linux_web_app.app
        File: /main.tf:48-63

Check: CKV_AZURE_9: "Ensure that RDP access is restricted from the internet"
        FAILED for resource: azurerm_network_security_group.nsg
        File: /main.tf:74-102

Check: CKV_AZURE_77: "Ensure that UDP Services are restricted from the Internet"
        FAILED for resource: azurerm_network_security_group.nsg
        File: /main.tf:74-102

Check: CKV2_AZURE_18: "Ensure that Storage Accounts use customer-managed key for encryption"
        FAILED for resource: azurerm_storage_account.data
        File: /main.tf:17-31

Check: CKV_AZURE_88: "Ensure that Managed identity provider is enabled for app services"
        FAILED for resource: azurerm_linux_web_app.app
        File: /main.tf:48-63

Check: CKV_AZURE_13: "Ensure App Service Authentication is set on Azure App Service"
        FAILED for resource: azurerm_linux_web_app.app
        File: /main.tf:48-63

Check: CKV_AZURE_17: "Ensure the web app has client certificates (Incoming client certificates)"
        FAILED for resource: azurerm_linux_web_app.app
        File: /main.tf:48-63

Check: CKV_AZURE_213: "Ensure that App Service configures TLS v1.2"
        FAILED for resource: azurerm_linux_web_app.app
        File: /main.tf:48-63

Check: CKV2_AZURE_tag: "Ensure resources have required tags"
        FAILED for resource: azurerm_storage_account.data
        FAILED for resource: azurerm_container_registry.acr
        FAILED for resource: azurerm_linux_web_app.app
        FAILED for resource: azurerm_network_security_group.nsg
```

## 1.5 Analisis de los hallazgos

Agrupemos los hallazgos por categoria de riesgo:

### Acceso a red

| Check | Recurso | Problema | Impacto |
|-------|---------|----------|---------|
| CKV_AZURE_9 | NSG | SSH abierto a 0.0.0.0/0 | Cualquiera puede intentar brute force SSH |
| CKV_AZURE_77 | NSG | Todos los puertos abiertos | Superficie de ataque maxima |

### Cifrado en transito

| Check | Recurso | Problema | Impacto |
|-------|---------|----------|---------|
| CKV_AZURE_3 | Storage | HTTPS no requerido | Datos en transito sin cifrar |
| CKV_AZURE_14 | Web App | HTTP permitido | Credenciales viajan en texto plano |
| CKV_AZURE_213 | Web App | TLS 1.2 no forzado | Protocolos TLS antiguos vulnerables |

### Gestion de identidad

| Check | Recurso | Problema | Impacto |
|-------|---------|----------|---------|
| CKV_AZURE_137 | ACR | Admin habilitado | Credenciales compartidas, sin auditoria individual |
| CKV_AZURE_88 | Web App | Sin managed identity | Necesita credenciales explicitas para acceder a otros servicios |

### Datos en reposo

| Check | Recurso | Problema | Impacto |
|-------|---------|----------|---------|
| CKV_AZURE_35 | Storage | Acceso publico a blobs | Datos sensibles accesibles sin autenticacion |
| CKV2_AZURE_18 | Storage | Sin CMK encryption | Sin control sobre las claves de cifrado |

!!! warning "Cada fallo = un riesgo real"
    Estos no son hallazgos teoricos. Cada uno de estos fallos ha sido explotado en incidentes reales. El storage publico ha causado filtraciones masivas de datos, y el SSH abierto es un vector clasico de ataque.

## 1.6 Generar reportes en diferentes formatos

```bash title="Checkov: diferentes formatos de salida"
# Formato JSON (para procesamiento automatizado)
checkov -d infrastructure/ --output json > checkov-report.json

# Formato SARIF (para integracion con Azure DevOps)
checkov -d infrastructure/ --output sarif > checkov-report.sarif

# Formato JUnit XML (para integracion con CI/CD)
checkov -d infrastructure/ --output junitxml > checkov-report.xml

# Multiples formatos a la vez
checkov -d infrastructure/ \
  --output cli \
  --output json \
  --output-file-path console,checkov-report.json
```

!!! info "Formato SARIF"
    SARIF (Static Analysis Results Interchange Format) es un estandar OASIS que permite integrar resultados de cualquier escaner en herramientas como Azure DevOps, GitHub Advanced Security, y VS Code.

## 1.7 Filtrar por severidad

```bash title="Checkov: filtrar checks"
# Solo checks de severidad HIGH y CRITICAL
checkov -d infrastructure/ --check-severity HIGH

# Excluir checks especificos (ej: tags)
checkov -d infrastructure/ --skip-check CKV2_AZURE_tag

# Solo un framework
checkov -d infrastructure/ --framework terraform --compact
```

!!! success "Paso Completado"
    Has escaneado el Terraform localmente con Checkov y encontrado 12+ misconfiguraciones de seguridad. En el siguiente paso integraremos este escaneo en el pipeline de Azure DevOps.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="index.md" class="md-button">Anterior: Introduccion</a>
  <a href="step2.md" class="md-button md-button--primary">Siguiente: Stage IaC en Pipeline</a>
</div>
