/**
 * # terraform-aci-l3out
 * 
 * Terraform module for Cisco ACI's L3Out configuration, supports high availability
 * via multiple paths. Supports vpc, port-channel and single interface paths.
 * Has support for ospf and bgp. To enable ospf ospf_enable must be set, if there are
 * any BGP settings, they will get applied
 * 
 */

/*
### Load in the tenant we're going to be working with as a data source
data "aci_tenant" "this" {
  name       = local.tenant_name
  annotation = "orchestrator:terraform"
}

### Load in the VRF we're deploying into as data source
data "aci_vrf" "this" {
  tenant_dn  = data.aci_tenant.this.id
  annotation = "orchestrator:terraform"
  name       = local.vrf
}

data "aci_l3_domain_profile" "this" {
  annotation = "orchestrator:terraform"
  name       = local.domain
}
*/

resource "aci_l3_outside" "this" {
  #  tenant_dn              = data.aci_tenant.this.id
  tenant_dn = local.tenant_dn
  #  relation_l3ext_rs_ectx = data.aci_vrf.this.id
  relation_l3ext_rs_ectx       = local.vrf_dn
  name                         = local.name
  relation_l3ext_rs_l3_dom_att = local.l3dom_dn
  #  relation_l3ext_rs_l3_dom_att = data.aci_l3_domain_profile.this.id
  enforce_rtctrl = local.enforce_route_control
}

resource "aci_logical_node_profile" "this" {
  l3_outside_dn = aci_l3_outside.this.id
  name          = "${local.name}-NodeP"
}

### Subnet configurations
resource "aci_external_network_instance_profile" "this" {
  for_each = local.external_epgs

  l3_outside_dn = aci_l3_outside.this.id
  name          = each.key
}

resource "aci_l3_ext_subnet" "this" {
  for_each = local.external_subnets

  external_network_instance_profile_dn = aci_external_network_instance_profile.this[each.value.external_epg].id
  ip                                   = each.value.subnet
  scope                                = each.value.scope
}

### Nodes
resource "aci_logical_node_to_fabric_node" "this" {
  for_each = local.nodes

  tdn    = each.value.node
  rtr_id = each.value.router_id

  logical_node_profile_dn = aci_logical_node_profile.this.id
  rtr_id_loop_back        = var.router_id_as_loopback
}

### Interfaces
resource "aci_logical_interface_profile" "this" {
  logical_node_profile_dn = aci_logical_node_profile.this.id
  name                    = "${local.name}-Intf"
}

resource "aci_logical_interface_profile" "thisv6" {
  for_each = local.v6_intf_profile

  logical_node_profile_dn = aci_logical_node_profile.this.id
  name                    = "${local.name}-Intf_v6"
}

/*
data "aci_fabric_path_ep" "this" {
  for_each = local.paths

  vpc        = each.value.is_vpc
  pod_id     = each.value.pod_id
  node_id    = join("-", each.value.nodes)
  name       = each.value.name
  annotation = "orchestrator:terraform"
}
*/

resource "aci_l3out_path_attachment" "this" {
  for_each = local.paths

  logical_interface_profile_dn = aci_logical_interface_profile.this.id
  #  target_dn                    = data.aci_fabric_path_ep.this[each.key].id
  target_dn = local.paths[each.key].path_dn
  if_inst_t = "ext-svi"
  encap     = "vlan-${each.value.vlan_id}"
  mtu       = each.value.mtu
  addr      = each.value.address
}


resource "aci_l3out_vpc_member" "this" {
  for_each = local.vpc_ip_addresses

  leaf_port_dn = aci_l3out_path_attachment.this[each.value.path_key].id
  side         = each.value.side
  addr         = each.value.ip_address
}

resource "aci_l3out_path_attachment" "thisv6" {
  for_each = local.pathsv6

  logical_interface_profile_dn = aci_logical_interface_profile.thisv6["v6"].id
  #  target_dn                    = data.aci_fabric_path_ep.this[each.key].id
  target_dn = local.paths[each.key].path_dn
  if_inst_t = "ext-svi"
  encap     = "vlan-${each.value.vlan_id}"
  mtu       = each.value.mtu
  addr      = each.value.address
}


resource "aci_l3out_vpc_member" "thisv6" {
  for_each = local.vpc_ip_addressesv6

  leaf_port_dn = aci_l3out_path_attachment.thisv6[each.value.path_key].id
  side         = each.value.side
  addr         = each.value.ip_address
}

resource "aci_l3out_path_attachment_secondary_ip" "this" {
  for_each = local.vpc_ip_addresses

  l3out_path_attachment_dn = aci_l3out_vpc_member.this[each.key].id
  addr                     = each.value.floating_address
}

resource "aci_l3out_path_attachment_secondary_ip" "thisv6" {
  for_each = local.vpc_ip_addressesv6

  l3out_path_attachment_dn = aci_l3out_vpc_member.thisv6[each.key].id
  addr                     = each.value.floating_address
}

### Routing
## Static

resource "aci_l3out_static_route" "this" {
  for_each = local.static_routes

  fabric_node_dn = aci_logical_node_to_fabric_node.this[each.value.node].id
  ip             = each.value.subnet
  aggregate      = "no"
}

resource "aci_l3out_static_route_next_hop" "this" {
  for_each = local.static_routes

  static_route_dn = aci_l3out_static_route.this[each.key].id
  nh_addr         = each.value.next_hop
}

## OSPF

resource "aci_ospf_interface_policy" "this" {
  for_each = local.ospf_timers

  #  tenant_dn    = data.aci_tenant.this.id
  tenant_dn    = local.tenant_dn
  name         = "${var.tenant_name}-OSPF-Pol"
  hello_intvl  = each.value.hello_interval
  dead_intvl   = each.value.dead_interval
  rexmit_intvl = each.value.retransmit_interval
  xmit_delay   = each.value.transmit_delay
  prio         = each.value.priority
}


resource "aci_l3out_ospf_interface_profile" "this" {
  for_each = local.ospf_timers

  logical_interface_profile_dn = aci_logical_interface_profile.this.id
  auth_key                     = local.ospf_auth.auth.key
  auth_key_id                  = local.ospf_auth.auth.key_id
  auth_type                    = local.ospf_auth.auth.type
  relation_ospf_rs_if_pol      = aci_ospf_interface_policy.this[each.key].id
}

resource "aci_l3out_ospf_external_policy" "this" {
  for_each = local.ospf_area

  l3_outside_dn = aci_l3_outside.this.id
  area_cost     = each.value.cost
  area_id       = each.value.id
  area_type     = each.value.type
}

## BGP 
resource "aci_l3out_bgp_external_policy" "this" {
  for_each = local.bgp_enable

  l3_outside_dn = aci_l3_outside.this.id
}

resource "aci_bgp_peer_connectivity_profile" "this" {
  for_each = local.bgp_peers

  parent_dn = aci_logical_node_profile.this.id
  addr      = each.value.address
  as_number = each.value.remote_as
  local_asn = each.value.local_as
}

resource "aci_bgp_peer_connectivity_profile" "intf_this" {
  for_each = local.intf_bgp_peers

  parent_dn = aci_l3out_path_attachment.this[0].id
  addr      = each.value.address
  as_number = each.value.remote_as
  local_asn = each.value.local_as
}