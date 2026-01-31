module "network" {
  source = "./network"
}

module "security" {
  source = "./security"
  vpc_id = module.network.vpc_id
}

resource "aws_key_pair" "key_pair" {
  key_name   = "key_pair"
  public_key = file("../keys/key.pub")
}

resource "aws_instance" "main" {
  ami             = var.ami
  subnet_id       = module.network.subnet_id
  instance_type   = var.instance_type
  key_name        = aws_key_pair.key_pair.id
  security_groups = [module.security.sg_id]

  tags = {
    Name = "Main"
  }
}