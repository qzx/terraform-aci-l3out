module "aci_l3out" {
  source      = "qzx/l3out/aci"
  version     = "0.0.2"

  name        = "example-l3out"
  tenant_name = "example"
  vrf         = "example"
  l3_domain   = "example-l3out-domain"

  paths = {
    primary = {
      name    = "eth1/2"
      pod_id  = 1
      nodes   = [101]
      is_vpc  = false
      vlan_id = 301
      mtu     = 1500
      interconnect_subnet = "172.16.0.0/30"
    }
  }

  static_routes = ["0.0.0.0/0"]
}