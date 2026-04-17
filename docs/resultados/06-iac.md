---
title: "Resultado 6 — Escaneo de IaC (Checkov)"
description: Hallazgos esperados del escaneo de infraestructura como código con Checkov sobre el Terraform vulnerable del workshop.
tags:
  - Resultados
  - IaC
  - Checkov
  - Terraform
---

# Stage 6 — Escaneo de IaC (Checkov)

<div class="lab-meta">
  <div class="lab-meta-item">
    <strong>Herramienta</strong>
    Checkov (Bridgecrew)
  </div>
  <div class="lab-meta-item">
    <strong>Archivo escaneado</strong>
    infrastructure/main.tf
  </div>
  <div class="lab-meta-item">
    <strong>Artefacto</strong>
    SARIF en GitHub Security
  </div>
  <div class="lab-meta-item">
    <strong>Hallazgos esperados</strong>
    ~10 misconfiguraciones
  </div>
</div>

---

## Que hace este stage

Checkov analiza el archivo `infrastructure/main.tf` en busca de **misconfiguraciones de seguridad** en los recursos de Azure definidos como Terraform. No despliega nada: es un analisis estatico del codigo de infraestructura. El resultado se sube como SARIF al tab de Security del repositorio.

---

## Hallazgos esperados

!!! failure "Checkov reporta ~10 checks fallidos"

| Check ID | Recurso | Descripcion del hallazgo |
|---|---|---|
| `CKV_AZURE_35` | `azurerm_storage_account.data` | Network access rule por defecto no es Deny |
| `CKV_AZURE_59` | `azurerm_storage_account.data` | Acceso publico a blobs habilitado |
| `CKV_AZURE_33` | `azurerm_storage_account.data` | Logging no habilitado para Queue service |
| `CKV_AZURE_44` | `azurerm_storage_account.data` | Sin reglas de red configuradas |
| `CKV_AZURE_3`  | `azurerm_storage_account.data` | HTTPS-only no habilitado |
| `CKV_AZURE_137`| `azurerm_container_registry.acr` | Admin user habilitado en ACR |
| `CKV_AZURE_14` | `azurerm_linux_web_app.app` | HTTPS-only no forzado en App Service |
| `CKV_AZURE_88` | `azurerm_linux_web_app.app` | Sin version minima de TLS |
| `CKV_AZURE_9`  | `azurerm_network_security_group.nsg` | SSH abierto a 0.0.0.0/0 |
| `CKV_AZURE_10` | `azurerm_network_security_group.nsg` | Regla permite todo el trafico entrante |

---

## Output esperado en el log

```text
Passed checks: 2, Failed checks: 10, Skipped checks: 0

Check: CKV_AZURE_35: "Ensure default network access rule for Storage Accounts is deny"
        FAILED for resource: azurerm_storage_account.data
        File: /main.tf:17-31

Check: CKV_AZURE_137: "Ensure ACR admin account is disabled"
        FAILED for resource: azurerm_container_registry.acr
        File: /main.tf:39-45

Check: CKV_AZURE_14: "Ensure web app redirects all HTTP traffic to HTTPS"
        FAILED for resource: azurerm_linux_web_app.app
        File: /main.tf:48-63

Check: CKV_AZURE_9: "Ensure that RDP access is restricted from the internet"
        FAILED for resource: azurerm_network_security_group.nsg
        File: /main.tf:74-102
```

---

## Donde verificar en GitHub

!!! tip "Tres lugares para consultar"

    1. **Actions** > click en el run > job **6. Escaneo de IaC** > logs del step "Checkov"
    2. **Security** > **Code scanning alerts** > filtrar por herramienta **checkov**
    3. **Actions** > click en el run > **Artifacts** > `checkov.sarif`

---

## Por que fallan estos checks

```hcl
# Storage con acceso publico y sin HTTPS
enable_https_traffic_only       = false   # CKV_AZURE_3
allow_nested_items_to_be_public = true    # CKV_AZURE_59

# ACR con admin habilitado
admin_enabled = true                      # CKV_AZURE_137

# App Service sin HTTPS
https_only = false                        # CKV_AZURE_14

# NSG abierto al mundo
source_address_prefix = "*"               # CKV_AZURE_9
destination_port_range = "*"              # CKV_AZURE_10
```

!!! info "Sin tags de compliance"
    Ningun recurso tiene tags (`environment`, `owner`, `cost-center`), lo que tambien puede generar warnings adicionales dependiendo de las politicas activas.

---

<div style="display: flex; justify-content: space-between; margin-top: 2rem;">
  <a href="05-image-scan/" class="md-button">:material-arrow-left: 5. Image Scan + Firma</a>
  <a href="../07-staging/" class="md-button md-button--primary">7. Deploy Staging :material-arrow-right:</a>
</div>
