provider "azurerm" {
  version = "~> 1.39"
}

terraform {
  backend "azurerm" {
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "RG-Fan2020-${var.environment}"
  location = var.location
}

resource "azurerm_virtual_network" "aks" {
  name                = "VNet-AKS-cluster"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks" {
  name                 = "Subnet-AKS-cluster"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefix       = "10.1.0.0/24"
}

resource "azurerm_virtual_network" "backend" {
  name                = "VNet-backend"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "backend" {
  name                 = "Subnet-backend"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.backend.name
  address_prefix       = "10.2.0.0/24"
}

resource "azurerm_virtual_network_peering" "peering1" {
  name                      = "vnetpeering1aks2backend"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.aks.name
  remote_virtual_network_id = azurerm_virtual_network.backend.id
}

resource "azurerm_virtual_network_peering" "peering2" {
  name                      = "vnetpeering1backend2aks"
  resource_group_name       = azurerm_resource_group.rg.name
  virtual_network_name      = azurerm_virtual_network.backend.name
  remote_virtual_network_id = azurerm_virtual_network.aks.id
}

