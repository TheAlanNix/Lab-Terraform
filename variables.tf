data "aws_availability_zones" "available" {}
variable "availability_zone_count" {
  default = 1
}
variable "dns_zone" {
  default = ""
}
variable "instance_ami" {}
variable "instance_key_name" {}
variable "instance_key_path" {}
variable "instance_size" {
  default = "t3.small"
}
variable "instance_username" {}
variable "instances_per_az" {
  default = 1
}
variable "lacework_access_token" {}
variable "region" {
  default = "us-east-1"
}
variable "vpc_name" {}
variable "vpc_subnet" {
  default = "10.150.0.0/24"
}
