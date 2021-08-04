module "aci_vpc_l3out" {
  source  = "qzx/l3out/aci"
  version = "1.0.0"

  name        = "example-l3out"
  tenant_name = "example"
  vrf         = "example"
  l3_domain   = "example-l3out-domain"

  paths = {
    primary = {
      name                = "EXAMPLE-VPC"
      pod_id              = 1
      nodes               = [101, 102]
      is_vpc              = true
      vlan_id             = 301
      mtu                 = 1500
      interconnect_subnet = "172.16.0.1/29"
    },
    secondary = {
      name                = "EXAMPLE-VPC"
      pod_id              = 2
      nodes               = [103, 104]
      is_vpc              = true
      vlan_id             = 301
      mtu                 = 1500
      interconnect_subnet = "172.16.0.1/29"
    }
  }

  ospf_enable = false

  ospf_timers = {
    hello_interval      = 5
    dead_interval       = 25
    retransmit_interval = 3
    transmit_delay      = 1
    priority            = 1
  }

  ospf_area = {
    id   = 1
    type = "nssa"
    cost = 1
  }
}