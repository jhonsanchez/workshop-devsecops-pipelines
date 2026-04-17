output "app_url" {
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
  description = "URL of the deployed application"
}

output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "ACR login server"
}
