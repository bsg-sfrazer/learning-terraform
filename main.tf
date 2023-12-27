data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

data "aws_vpc" "default" {
  default = true
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "blog" {
  ami                    = data.aws_ami.app_ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [ module.blog_sg.security_group_id ]

  subnet_id = module.blog_vpc.public_subnets[0]

  tags = {
    Name = "HelloWorld"
  }
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name            = "myblog-alb"
  vpc_id          = module.blog_vpc.vpc_id
  subnets         = module.blog_cpv.public_subnets
  security_groups = module.blog_sg.security_group_id

  listeners = {
    ex_http = {
      port                        = 80
      protocol                    = "HTTP"

      forward = {
        # The value of the `target_group_key` is the key used in the `target_groups` map below
        target_group_key = "ex-instance"
      }
    }
  }

  target_groups = {
    # This key name is used by the listener/listener rules to know which target to forward traffic to
    ex_instance = {
      name_prefix                       = "blog"
      protocol                          = "HTTP"
      port                              = 80
      target_type                       = "instance"
      deregistration_delay              = 10
      load_balancing_cross_zone_enabled = true
    }
  }

  tags = {
    Environment = "Dev"
  }
}

module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"
  name    = "blog"

  vpc_id = module.blog_vpc.vpc_id

  ingress_rules       = [ "http-80-tcp", "https-443-tcp" ]
  ingress_cidr_blocks = [ "0.0.0.0/0" ]
  egress_rules        = [ "all-all" ]
  egress_cidr_blocks  = [ "0.0.0.0/0" ]
}
