variable "cluster_name"       { type = string }
variable "kubernetes_version"  { type = string; default = "1.29" }
variable "private_subnet_ids"  { type = list(string) }
variable "node_instance_type"  { type = string; default = "t3.medium" }
variable "node_desired"        { type = number; default = 2 }
variable "node_min"            { type = number; default = 1 }
variable "node_max"            { type = number; default = 5 }
variable "allowed_cidr_blocks" { type = list(string); default = ["0.0.0.0/0"] }
# CHANGE THIS: Lock down to your home IP for security e.g. ["203.0.113.42/32"]
variable "tags"                { type = map(string); default = {} }
