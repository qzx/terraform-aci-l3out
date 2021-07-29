module "aci_ha_mpls_l3out" {
  source  = "qzx/l3out/aci"
  version = "0.0.2"

  name        = "example-l3out"
  tenant_name = "example"
  vrf         = "example"
  l3_domain   = "MPLS-Provider-L3-Domain"


  router_id_as_loopback = true

  paths = {
    primary = {
      name                = "eth1/22"
      pod_id              = 1
      nodes               = [101]
      is_vpc              = false
      vlan_id             = 301
      mtu                 = 1500
      interconnect_subnet = "172.16.1.0/29"
    },
    primary = {
      name                = "eth1/22"
      pod_id              = 1
      nodes               = [102]
      is_vpc              = false
      vlan_id             = 301
      mtu                 = 1500
      interconnect_subnet = "172.16.1.4/29"
    }
  }

  external_epgs = {
    FW-Subnets = {
      subnets = ["0.0.0.0/0"]
      scope   = ["import-security"]
    }
    Servers = {
      subnets = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"]
      scope   = ["shared-rtctrl", "shared-security", "import-security"]
    }
  }

  bgp_peers = {
    primary = {
      address   = "172.16.1.1"
      local_as  = 10
      remote_as = 200
      password  = "provider-password-1"
    },
    secondary = {
      address   = "172.16.1.5"
      local_as  = 10
      remote_as = 300
      password  = "provider-password-2"
    }
  }
}