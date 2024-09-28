provider "aws" {
  region = var.region
}

module "vpc" {
  source = "./modules/vpc"
  region = var.region
}

variable "MONGO_URL" {
  description = "URL de conexão do MongoDB"
  type        = string
  sensitive   = true
}


module "eks" {
  source             = "./modules/eks"
  region             = var.region
  vpc_id             = module.vpc.id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  MONGO_URL          = var.MONGO_URL
}



