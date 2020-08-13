variable "region" {
  type = string
  default = "us-west-2"
}

variable "cidr_block" {
  type = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type = map(any)
  default = {
    "us-west-1": ["us-west-1a", "us-west-1c"],
    "us-west-2": ["us-west-2a", "us-west-2c"],
    "us-east-1": ["us-east-1a", "us-east-1c"],
    "us-east-2": ["us-east-2a", "us-east-2c"]
  }
}

variable "private_subnets" {
  type = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.3.0/24"
  ]
}

variable "public_subnets" {
  type = list(string)
  default = [
    "10.0.200.0/24",
    "10.0.203.0/24"
  ]
}

variable "enable_nat_gateway" {
  type = bool
  default = false
}

variable "enable_vpn_gateway" {
  type = bool
  default = false
}
