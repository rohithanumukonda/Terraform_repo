module "my_vpc" {
  source = "../Day-5-modules"

  vpc_cidr = var.vpc_cidr
  vpc_name = var.vpc_name
}