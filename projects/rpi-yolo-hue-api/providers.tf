provider "azurerm" {
  features {}

  subscription_id = var.subscription_id

  # AzureRM v5 does not register resource providers by default. Register only
  # the services this stack and its Azure Machine Learning workflows require.
  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.ContainerRegistry",
    "Microsoft.KeyVault",
    "Microsoft.MachineLearningServices",
    "Microsoft.Notebooks",
    "Microsoft.OperationalInsights",
    "Microsoft.Storage",
    "microsoft.insights",
  ]
}

