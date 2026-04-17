# VULNERABLE Terraform — intentionally insecure for Lab 9
# This file contains misconfigurations that Checkov will detect

provider "azurerm" {
  features {}
}

variable "environment" {
  default = "staging"
}

variable "image_tag" {
  default = "latest"
}

# VULNERABLE: Storage account with public access (CKV_AZURE_35)
resource "azurerm_storage_account" "data" {
  name                     = "entelgyworkshopdata"
  resource_group_name      = azurerm_resource_group.workshop.name
  location                 = azurerm_resource_group.workshop.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # VULNERABLE: Public blob access enabled
  allow_nested_items_to_be_public = true

  # VULNERABLE: No encryption with customer-managed key
  # VULNERABLE: No network rules (open to all)
  # VULNERABLE: HTTPS-only not enforced
  enable_https_traffic_only = false
}

resource "azurerm_resource_group" "workshop" {
  name     = "rg-workshop-${var.environment}"
  location = "West Europe"
}

# VULNERABLE: Container registry without admin disabled (CKV_AZURE_137)
resource "azurerm_container_registry" "acr" {
  name                = "entelgyworkshopacr"
  resource_group_name = azurerm_resource_group.workshop.name
  location            = azurerm_resource_group.workshop.location
  sku                 = "Basic"
  admin_enabled       = true  # VULNERABLE: Admin user should be disabled
}

# VULNERABLE: App Service without HTTPS-only (CKV_AZURE_14)
resource "azurerm_linux_web_app" "app" {
  name                = "workshop-app-${var.environment}"
  resource_group_name = azurerm_resource_group.workshop.name
  location            = azurerm_resource_group.workshop.location
  service_plan_id     = azurerm_service_plan.plan.id

  # VULNERABLE: HTTPS not enforced
  https_only = false

  site_config {
    # VULNERABLE: No minimum TLS version set
    # VULNERABLE: No managed identity
  }

  # VULNERABLE: No tags for compliance
}

resource "azurerm_service_plan" "plan" {
  name                = "plan-workshop-${var.environment}"
  resource_group_name = azurerm_resource_group.workshop.name
  location            = azurerm_resource_group.workshop.location
  os_type             = "Linux"
  sku_name            = "B1"
}

# VULNERABLE: Network security group with open SSH (CKV_AZURE_9)
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-workshop-${var.environment}"
  location            = azurerm_resource_group.workshop.location
  resource_group_name = azurerm_resource_group.workshop.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"       # VULNERABLE: Open to 0.0.0.0/0
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAll"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"        # VULNERABLE: All ports open
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
