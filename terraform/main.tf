# =============================================================================
# BASELINE (intentionally insecure) infrastructure to host the ForgeTask SaaS.
# Each resource has a comment explaining WHY it is needed.
# =============================================================================

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# 1) Resource group: container of every baseline resource (inspect, tag, destroy as one unit).
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.name_prefix}-baseline"
  location = var.location

  tags = {
    project = "bok-security-engineering"
    stage   = "baseline-insecure"
  }
}

data "azurerm_client_config" "current" {}

# 2) Virtual network + ONE flat subnet: the private IP space of the nodes (the OCI VCN).
#    Flat on purpose: segmentation is a control added later.
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.name_prefix}"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-flat"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

# 3) Container registry (ACR): the CI/CD pushes the two images here and the cluster pulls them (OCIR).
resource "azurerm_container_registry" "acr" {
  name                = "acr${var.name_prefix}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = false
}

# 4) AKS cluster (the OKE): Free tier (no control-plane fee, no SLA), public API endpoint,
#    Azure CNI in the flat subnet, no network policy (no pod microsegmentation yet).
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${var.name_prefix}-baseline"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${var.name_prefix}-baseline"
  sku_tier            = "Free"

  default_node_pool {
    name           = "system"
    node_count     = var.node_count
    vm_size        = var.node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
    zones          = length(var.zones) > 0 ? var.zones : null
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = "10.20.0.0/16"
    dns_service_ip = "10.20.0.10"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  key_vault_secrets_provider {
    secret_rotation_enabled = true 
  }

  node_provisioning_profile {
    mode = "Manual" 
  }
}

# 5) AcrPull: without it the nodes cannot download images (ImagePullBackOff).
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

resource "azurerm_key_vault" "kv" {
  name = "kv-${var.name_prefix}-secrets"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  tenant_id = data.azurerm_client_config.current.tenant_id
  sku_name = "standard"

  rbac_authorization_enabled = true
  purge_protection_enabled = true
  soft_delete_retention_days = 7
}

resource "azurerm_user_assigned_identity" "workload_identity" {
  name                = "id-aks-${var.name_prefix}-forgetask"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "kv_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload_identity.principal_id
}

resource "azurerm_federated_identity_credential" "federated_credential" {
  name                = "fic-${var.name_prefix}-forgetask-sa"
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  user_assigned_identity_id = azurerm_user_assigned_identity.workload_identity.id
  subject             = "system:serviceaccount:forgetask:forgetask-sa"
} 