output "resource_group_name" {
  description = "Resource group containing the project resources."
  value       = azurerm_resource_group.project.name
}

output "storage_account_name" {
  description = "Generated globally unique storage account name."
  value       = azurerm_storage_account.images.name
  sensitive   = true
}

output "images_container_name" {
  description = "Private blob container used for project images."
  value       = azurerm_storage_container.images.name
}

output "primary_blob_endpoint" {
  description = "Blob service endpoint for application configuration."
  value       = azurerm_storage_account.images.primary_blob_endpoint
  sensitive   = true
}

output "machine_learning_workspace_name" {
  description = "Azure Machine Learning workspace shown in Azure Machine Learning Studio."
  value       = azurerm_machine_learning_workspace.project.name
}

output "machine_learning_workspace_id" {
  description = "Resource ID of the Azure Machine Learning workspace."
  value       = azurerm_machine_learning_workspace.project.id
}

output "machine_learning_studio_url" {
  description = "Azure Machine Learning Studio entry point."
  value       = "https://ml.azure.com"
}

output "log_analytics_workspace_name" {
  description = "Log Analytics workspace used by Application Insights."
  value       = azurerm_log_analytics_workspace.machine_learning.name
}

