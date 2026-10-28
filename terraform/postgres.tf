# =============================================================================
# Database: Azure Database for PostgreSQL Flexible Server (replaces Oracle ATP).
# Needed because the SaaS stores users, projects and roles. Login/signup only touch
# PROJECT, USER_ACCOUNT and USER_ROLE.
# =============================================================================

# 6) Database server. Burstable B1ms = smallest/cheapest compute tier.
#    Public access on purpose in the baseline (exposure is analysed later, risk R-03).
resource "azurerm_postgresql_flexible_server" "db" {
  name                          = "psql-${var.name_prefix}-${random_string.suffix.result}"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  version                       = "16"
  administrator_login           = var.db_admin_login
  administrator_password        = var.db_admin_password
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  backup_retention_days         = 7
  public_network_access_enabled = true

  lifecycle {
    ignore_changes = [zone]
  }
}

# 7) The logical database the app connects to.
resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "forgetask"
  server_id = azurerm_postgresql_flexible_server.db.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# 8) Firewall rule 0.0.0.0 - 0.0.0.0 = "allow Azure services": lets the AKS pods reach the server.
#    Convenient and too open: a deliberate baseline weakness to harden later.
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.db.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
