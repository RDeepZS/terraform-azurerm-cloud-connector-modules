################################################################################
# Create Gateway Load Balancer Resources
################################################################################

# Create Gateway Load Balancer
resource "azurerm_lb" "cc_gwlb" {
  name                = "${var.name_prefix}-cc-gwlb-${var.resource_tag}"
  location            = var.location
  resource_group_name = var.resource_group
  sku                 = "Gateway"  # GWLB-specific SKU

  tags = var.global_tags

  # Frontend IP Configuration
  frontend_ip_configuration {
    name                          = "${var.name_prefix}-cc-gwlb-ip-${var.resource_tag}"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
    zones                         = local.zones_supported ? local.frontend_zone_specific : null
  }
}


################################################################################
# Create Backend Address Pool for Gateway Load Balancer
################################################################################

resource "azurerm_lb_backend_address_pool" "cc_gwlb_backend_pool" {
  name            = "${var.name_prefix}-cc-gwlb-backend-${var.resource_tag}"
  loadbalancer_id = azurerm_lb.cc_gwlb.id

  # Tunnel Interfaces for VXLAN Traffic
  tunnel_interface {
    port       = var.vxlan_internal_port       # Internal VXLAN Port (e.g., 4789)
    identifier = var.vxlan_internal_vni       # Internal VXLAN VNI (e.g., 600)
    protocol   = "VXLAN"
    type       = "Internal"
  }

  tunnel_interface {
    port       = var.vxlan_external_port       # External VXLAN Port (e.g., 4789)
    identifier = var.vxlan_external_vni       # External VXLAN VNI (e.g., 500)
    protocol   = "VXLAN"
    type       = "External"
  }
}

################################################################################
# Define Gateway Load Balancer Health Probe Parameters
################################################################################
resource "azurerm_lb_probe" "cc_gwlb_probe" {
  name                = "${var.name_prefix}-cc-lb-probe-${var.resource_tag}"
  loadbalancer_id     = azurerm_lb.cc_gwlb.id
  protocol            = "Http"
  port                = var.http_probe_port
  request_path        = "/?cchealth"
  interval_in_seconds = var.health_probe_interval
  probe_threshold     = var.probe_threshold
  number_of_probes    = var.number_of_probes
}

################################################################################
# Create Gateway Load Balancer Rules
################################################################################

resource "azurerm_lb_rule" "cc_gwlb_rule" {
  name                           = "${var.name_prefix}-cc-gwlb-rule-${var.resource_tag}"
  loadbalancer_id                = azurerm_lb.cc_gwlb.id
  protocol                       = "All"                  # GWLB rules usually use "All" for VXLAN traffic
  frontend_port                  = 0                     # GWLB rules use port `0` to allow encapsulated VXLAN traffic
  backend_port                   = 0                     # Backend pool port is also set to `0`
  frontend_ip_configuration_name = azurerm_lb.cc_gwlb.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.cc_gwlb_backend_pool.id]  # Wrap backend pool in a list
  probe_id                       = azurerm_lb_probe.cc_gwlb_probe.id
}

