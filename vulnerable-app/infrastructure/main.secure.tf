# SECURE Terraform — hardened version revealed in Lab 9
# All Checkov findings from main.tf have been resolved

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "workshop" {
  name     = "rg-workshop-${var.environment}"
  location = var.location

  tags = {
    Environment = var.environment
    Project     = "DevSecOps Workshop"
    Owner       = "security-team@entelgy.com"
    ManagedBy   = "Terraform"
  }
}

# SECURE: Storage account with all protections enabled
resource "azurerm_storage_account" "data" {
  name                     = "entelgyworkshopdata${var.environment}"
  resource_group_name      = azurerm_resource_group.workshop.name
  location                 = azurerm_resource_group.workshop.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  # SECURE: Public access disabled
  allow_nested_items_to_be_public = false

  # SECURE: HTTPS enforced
  enable_https_traffic_only = true

  # SECURE: Minimum TLS version
  min_tls_version = "TLS1_2"

  # SECURE: Network rules — deny by default
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = azurerm_resource_group.workshop.tags
}

# SECURE: Container registry with admin disabled
resource "azurerm_container_registry" "acr" {
  name                = "entelgyworkshopacr${var.environment}"
  resource_group_name = azurerm_resource_group.workshop.name
  location            = azurerm_resource_group.workshop.location
  sku                 = "Standard"
  admin_enabled       = false

  tags = azurerm_resource_group.workshop.tags
}

# SECURE: App Service with all security controls
resource "azurerm_linux_web_app" "app" {
  name                = "workshop-app-${var.environment}"
  resource_group_name = azurerm_resource_group.workshop.name
  location            = azurerm_resource_group.workshop.location
  service_plan_id     = azurerm_service_plan.plan.id

  # SECURE: HTTPS enforced
  https_only = true

  site_config {
    minimum_tls_version = "1.2"

    application_stack {
      docker_image_name   = "${azurerm_container_registry.acr.login_server}/${var.image_name}:${var.image_tag}"
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = azurerm_resource_group.workshop.tags
}

resource "azurerm_service_plan" "plan" {
  name                = "plan-workshop-${var.environment}"
  resource_group_name = azurerm_resource_group.workshop.name
  location            = azurerm_resource_group.workshop.location
  os_type             = "Linux"
  sku_name            = "B1"

  tags = azurerm_resource_group.workshop.tags
}

# SECURE: NSG with restrictive rules only
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-workshop-${var.environment}"
  location            = azurerm_resource_group.workshop.location
  resource_group_name = azurerm_resource_group.workshop.name

  # Only allow HTTPS from known CIDR
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "10.0.0.0/8"
    destination_address_prefix = "*"
  }

  # Deny all other inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = azurerm_resource_group.workshop.tags
}
