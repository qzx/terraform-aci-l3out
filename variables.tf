variable "name" {
  type        = string
  description = "Name of our new L3Out"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]{0,64}$", var.name))
    error_message = "Allowed characters: `a`-`z`, `A`-`Z`, `0`-`9`, `_`, `.`, `-`. Maximum characters: 64."
  }
}

variable "tenant_name" {
  type        = string
  description = "The tenant we want to deploy our L3Out into"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]{0,64}$", var.tenant_name))
    error_message = "Allowed characters: `a`-`z`, `A`-`Z`, `0`-`9`, `_`, `.`, `-`. Maximum characters: 64."
  }
}

variable "vrf" {
  type        = string
  description = "The associated VRF we are deploying into"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_.-]{0,64}$", var.vrf))
    error_message = "Allowed characters: `a`-`z`, `A`-`Z`, `0`-`9`, `_`, `.`, `-`. Maximum characters: 64."
  }
}

variable "vrf_id" {
  type        = number
  description = "The ID of the VRF being used, this is required for the router ID generation if the module is already managing an L3Out in the same tenant but different VRF"
  default     = 1

  validation {
    condition     = var.vrf_id >= 1 && var.vrf_id <= 254
    error_message = "Value has to be between 1 and 254."
  }
}

variable "l3_domain" {
  type        = string
  description = "The Layer3 domain this L3Out belongs to"
}

variable "router_id_as_loopback" {
  type        = bool
  description = "Set to true if router IDs should be installed as loopback addresses to respective switches"
  default     = false
}

variable "paths" {
  type = map(object({
    name                = string,
    pod_id              = number,
    nodes               = list(number),
    is_vpc              = bool,
    vlan_id             = number,
    mtu                 = number,
    interconnect_subnet = string,
  }))
  description = "The interface path to which we will deploy the L3Out"
}

variable "pathsv6" {
  type = map(object({
    name                = string,
    pod_id              = number,
    nodes               = list(number),
    is_vpc              = bool,
    vlan_id             = number,
    mtu                 = number,
    interconnect_subnet = string,
  }))
  description = "The interface path to which we will deploy the L3Out IPv6 Address"
  default     = {}
}

variable "external_epgs" {
  type = map(object({
    subnets = list(string),
    scope   = list(string),
  }))
  description = "Map of external EPGs to create as network objects"
  default = {
    default = {
      subnets = ["0.0.0.0/0"],
      scope   = ["import-security"]
    }
  }
}

variable "static_routes" {
  type        = list(string)
  description = "List of subnets in CIDR notation to be statically routed to the first IP address of the interconnect subnet"
  default     = []
}

variable "ospf_enable" {
  type        = bool
  description = "Enable OSPF, timers and area settings can be over written with ospf_area and ospf_timers"
  default     = false
}

variable "ospf_area" {
  type = object({
    id   = string,
    type = string,
    cost = number,
  })
  description = "OSPF Area settings"
  default = {
    id   = "backbone"
    type = "regular"
    cost = 1
  }
}

variable "ospf_timers" {
  type = object({
    hello_interval      = number,
    dead_interval       = number,
    retransmit_interval = number,
    transmit_delay      = number,
    priority            = number,
  })
  description = "Optional ospf timing configuration to pass on, sensible defaults are provided"
  default = {
    hello_interval      = 10
    dead_interval       = 40
    retransmit_interval = 5
    transmit_delay      = 1
    priority            = 1
  }
}

variable "ospf_auth" {
  type = object({
    key    = string,
    key_id = number,
    type   = string,
  })
  description = "OSPF authentication settings if ospf is enabled, key_id can range from 1-255 and key_type can be: md5, simple or none"
  default = {
    key    = ""
    key_id = 1
    type   = "none"
  }
}

variable "bgp_peers" {
  type = map(object({
    address   = string,
    local_as  = number,
    remote_as = number,
    password  = string,
  }))
  description = "BGP Neighbour configuration, having a neighbour causes BGP to be enabled, nodes must have loopbacks (enable router_id_as_loopback)"
  default     = {}
}

variable "intf_bgp_peers" {
  type = map(object({
    address   = string,
    local_as  = number,
    remote_as = number,
    password  = string,
  }))
  description = "BGP Neighbour configuration for interface bound profiles. no loopback required"
  default     = {}
}

variable "inbound_filter" {
  type        = bool
  description = "If enabled the module will create inbound filter lists based on the subnets in the EPGs provided and enforce inbound filtering"
  default     = false
}

locals {
  ospf_area   = var.ospf_enable ? { area = var.ospf_area } : {}
  ospf_timers = var.ospf_enable ? { timers = var.ospf_timers } : {}
  ospf_auth   = var.ospf_enable ? { auth = var.ospf_auth } : {}
}

locals {
  bgp_peers      = var.bgp_peers
  intf_bgp_peers = var.intf_bgp_peers
  bgp_enable     = length(var.bgp_peers) > 0 ? { "enable" = "yes" } : {}
}

locals {
  node_list = distinct(
    flatten([
      for path_key, path in var.paths : [
        for node in path.nodes : {
          node                = "topology/pod-${path.pod_id}/node-${node}"
          router_id           = "1.${path.pod_id}.${node}.${var.vrf_id}"
          path_key            = path_key
          node_id             = node
          is_vpc              = path.is_vpc
          interconnect_subnet = path.interconnect_subnet
        }
      ]
    ])
  )
}

locals {
  node_listv6 = distinct(
    flatten([
      for path_key, path in var.pathsv6 : [
        for node in path.nodes : {
          node                = "topology/pod-${path.pod_id}/node-${node}"
          router_id           = "1.${path.pod_id}.${node}.${var.vrf_id}"
          path_key            = path_key
          node_id             = node
          is_vpc              = path.is_vpc
          interconnect_subnet = path.interconnect_subnet
        }
      ]
    ])
  )
}

locals {
  vpc_ip_addresses = {
    for node in local.vpc_nodes : node.node => {
      path_key = node.path_key
      ip_address = join("/",
        [
          cidrhost(
            node.interconnect_subnet,
            (index(local.node_list, node) + 2)
          ),
          split("/", node.interconnect_subnet)[1]
        ]
      )
      side = (node.node_id % 2 == 0 ? "B" : "A")
      floating_address = join("/",
        [
          cidrhost(
            node.interconnect_subnet,
            -2
          ),
          split("/", node.interconnect_subnet)[1]
        ]
      )
    }
  }
}

locals {
  vpc_ip_addressesv6 = {
    for node in local.vpc_nodesv6 : node.node => {
      path_key = node.path_key
      ip_address = join("/",
        [
          cidrhost(
            node.interconnect_subnet,
            (index(local.node_listv6, node) + 2)
          ),
          split("/", node.interconnect_subnet)[1]
        ]
      )
      side = (node.node_id % 2 == 0 ? "B" : "A")
      floating_address = join("/",
        [
          cidrhost(
            node.interconnect_subnet,
            -2
          ),
          split("/", node.interconnect_subnet)[1]
        ]
      )
    }
  }
}

locals {
  paths = {
    for key, path in var.paths : key => {
      path_dn = length(path.nodes) > 1 ? "topology/pod-${path.pod_id}/protpaths-${join("-", path.nodes)}/pathep-[${path.name}]" : "topology/pod-${path.pod_id}/paths-${path.nodes[0]}/pathep-[${path.name}]"
      name    = path.name,
      pod_id  = path.pod_id,
      nodes   = path.nodes,
      is_vpc  = path.is_vpc,
      vlan_id = path.vlan_id,
      mtu     = path.mtu,
      address = path.is_vpc ? "0.0.0.0" : join("/",
        [
          cidrhost(
            path.interconnect_subnet,
            -2
          ),
          split("/", path.interconnect_subnet)[1]
        ]
      )
      interconnect_subnet = path.interconnect_subnet
    }
  }
  external_epgs = var.external_epgs
  vrf           = var.vrf
}

locals {
  pathsv6 = {
    for key, path in var.pathsv6 : key => {
      path_dn = length(path.nodes) > 1 ? "topology/pod-${path.pod_id}/protpaths-${join("-", path.nodes)}/pathep-[${path.name}]" : "topology/pod-${path.pod_id}/paths-${path.nodes[0]}/pathep-[${path.name}]"
      name    = path.name,
      pod_id  = path.pod_id,
      nodes   = path.nodes,
      is_vpc  = path.is_vpc,
      vlan_id = path.vlan_id,
      mtu     = path.mtu,
      address = path.is_vpc ? "::/0" : join("/",
        [
          cidrhost(
            path.interconnect_subnet,
            -2
          ),
          split("/", path.interconnect_subnet)[1]
        ]
      )
      interconnect_subnet = path.interconnect_subnet
    }
  }
}


locals {
  external_subnet_list = flatten([
    for epg_key, epg in var.external_epgs : [
      for subnet in epg.subnets : {
        external_epg = epg_key
        subnet       = subnet
        scope        = epg.scope
        key          = "${epg_key}/${subnet}"
      }
    ]
  ])
  domain      = var.l3_domain
  name        = var.name
  tenant_name = var.tenant_name
}

locals {
  tenant_dn = join("-", ["uni/tn", local.tenant_name])
}

locals {
  vrf_rn = join("/", [local.tenant_dn, "ctx"])
}

locals {
  vrf_dn = join("-", [local.vrf_rn, var.vrf])
}

locals {
  l3dom_dn = join("-", ["uni/l3dom", var.l3_domain])
}

locals {
  static_route_list = flatten([
    for node in local.nodes : [
      for subnet in var.static_routes : {
        key      = join("/", [node.node, subnet])
        subnet   = subnet
        next_hop = cidrhost(node.interconnect_subnet, 1)
        node     = node.node
      }
    ]
  ])
}

locals {
  static_routes = {
    for route in local.static_route_list : route.key => route
  }
  nodes = {
    for node in local.node_list : node.node => node
  }
  vpc_nodes = {
    for node in local.node_list : node.node => node if node.is_vpc
  }
  vpc_nodesv6 = {
    for node in local.node_listv6 : node.node => node if node.is_vpc
  }
  external_subnets = {
    for subnet in local.external_subnet_list : subnet.key => subnet
  }
  enforce_route_control = var.inbound_filter ? ["export", "import"] : ["export"]
  v6_intf_profile       = length(local.node_listv6) > 0 ? { "v6" : "node" } : {}
}
