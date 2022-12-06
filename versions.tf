terraform {
  required_version = "~> 1.2.9"

  required_providers {
    aci = {
      source  = "CiscoDevNet/aci"
      version = "~> 2.5.2"
    }
  }
}