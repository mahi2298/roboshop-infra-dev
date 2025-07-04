module "frontend" {
    #source = "../../terraform-aws-security-group-module"
    source = "git::https://github.com/mahi2298/terraform-aws-security-group-module.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = var.frontend_sg_name
    sg_description = var.frontend_sg_description
    vpc_id = local.vpc_id # retrieving the vpc id using data source and calling that value here
}

# here we are storing this value in ssm parameter store i.e. in parameters.tf
output "sg_id" {
    value = module.frontend.sg_id # here .sg_id is exposed from output of terraform-aws-security-group-module
}

# creating the security group for bastion server
module "bastion" {
    source = "git::https://github.com/mahi2298/terraform-aws-security-group-module.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = var.bastion_sg_name
    sg_description = var.bastion_sg_description
    vpc_id = local.vpc_id
}

# creating security group for application load balancer
module "backend_alb" {
    source = "git::https://github.com/mahi2298/terraform-aws-security-group-module.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = "backend-alb"
    sg_description = "backend-application-load-balancer"
    vpc_id = local.vpc_id
}

module "openvpn" {
    source ="git::https://github.com/mahi2298/terraform-aws-security-group-module.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = "openvpn"
    sg_description = "for openvpn connection"
    vpc_id = local.vpc_id
}

module "mongodb" {
    source ="git::https://github.com/mahi2298/terraform-aws-security-group-module.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = "mongodb"
    sg_description = "for mongodb connection"
    vpc_id = local.vpc_id
}

module "redis" {
    source ="git::https://github.com/mahi2298/terraform-aws-security-group-module.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = "redis"
    sg_description = "for redis connection"
    vpc_id = local.vpc_id
}

module "mysql" {
    source ="git::https://github.com/mahi2298/terraform-aws-security-group-module.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = "mysql"
    sg_description = "for mysql connection"
    vpc_id = local.vpc_id
}

module "rabbitmq" {
    source ="git::https://github.com/mahi2298/terraform-aws-security-group-module.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = "rabbitmq"
    sg_description = "for rabbitmq connection"
    vpc_id = local.vpc_id
}

module "catalogue" {
    source = "git::https://github.com/mahi2298/terraform-aws-security-group-module.git?ref=main"
    project = var.project
    environment = var.environment
    sg_name = "catalogue"
    sg_description = "for catalogue connection"
    vpc_id = local.vpc_id
}


# giving connection from laptop to bastion by creating the security group for basiton and allowing only incoming traffic on port 22 for bastion
resource "aws_security_group_rule" "bastion_laptop" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = module.bastion.sg_id
}

# giving connection from bastion to alb by creating the security group for backend-alb and allowing only port 80 and also sg-id of bastion to alb as the incoming traffic
# bcoz for load balancer incoming traffic of port 80 only will be allowed in order to get trrafic from outside we are using the sg-id of bastion bcoz this bastion will be in public subnet 
# from laptop --> bastion server (created in public subnet) --> load balancer (created in private subnet)
resource "aws_security_group_rule" "backend_alb_bastion" {
    type = "ingress" 
    from_port = 80 # allowing port 80 as incoming traffic
    to_port = 80 # allowing port 80 as incoming traffic
    protocol = "tcp"
    source_security_group_id = module.bastion.sg_id # taking the sg id of bastion and attaching it to to backend-alb as incoming traffic
    security_group_id = module.backend_alb.sg_id # backend-alb security id
}

# making the connection from load balancer to openvpn in order to make the connection
resource "aws_security_group_rule" "loadbalancer_openvpn" {
    type = "ingress"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    source_security_group_id = module.openvpn.sg_id # attaching the openvpn sg_id to load balancer to make connection between load balancer and openvpn
    # if user connects to openvpn client and user is in that region he will directly to the load balancer through DNS Name
    security_group_id = module.backend_alb.sg_id # load balancer security group id
}

#vpn ports are 22,443,1194,943
resource "aws_security_group_rule" "vpn_ssh" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = module.openvpn.sg_id
}

resource "aws_security_group_rule" "vpn_https" {
    type = "ingress"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = module.openvpn.sg_id
}

resource "aws_security_group_rule" "vpn_1194" {
    type = "ingress"
    from_port = 1194
    to_port = 1194
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = module.openvpn.sg_id
}

resource "aws_security_group_rule" "vpn_943" {
    type = "ingress"
    from_port = 943
    to_port = 943
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = module.openvpn.sg_id
}

#mongodb port from openvpn
resource "aws_security_group_rule" "mongodb_ports_vpn" {
    count = length(var.mongodb_ports_vpn)
    type = "ingress"
    from_port = var.mongodb_ports_vpn[count.index]
    to_port = var.mongodb_ports_vpn[count.index]
    protocol = "tcp"
    source_security_group_id = module.openvpn.sg_id
    security_group_id = module.mongodb.sg_id
}

#redis ports from openvpn
resource "aws_security_group_rule" "redis_ports_vpn" {
    count = length(var.redis_ports_vpn)
    type = "ingress"
    from_port = var.redis_ports_vpn[count.index]
    to_port = var.redis_ports_vpn[count.index]
    protocol = "tcp"
    source_security_group_id = module.openvpn.sg_id
    security_group_id = module.redis.sg_id
}

#mysql ports from openvpn
resource "aws_security_group_rule" "mysql_ports_vpn" {
    count = length(var.mysql_ports_vpn)
    type = "ingress"
    from_port = var.mysql_ports_vpn[count.index]
    to_port = var.mysql_ports_vpn[count.index]
    protocol = "tcp"
    source_security_group_id = module.openvpn.sg_id
    security_group_id = module.mysql.sg_id
}

#rabbitmq ports from openvpn
resource "aws_security_group_rule" "rabbitmq_ports_vpn" {
    count = length(var.rabbitmq_ports_vpn)
    type = "ingress"
    from_port = var.rabbitmq_ports_vpn[count.index]
    to_port = var.rabbitmq_ports_vpn[count.index]
    protocol = "tcp"
    source_security_group_id = module.openvpn.sg_id
    security_group_id = module.rabbitmq.sg_id
}

#catalogue ports 
#alb to catalogue port 8080
resource "aws_security_group_rule" "backend_alb_catalogue" {
    type = "ingress"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    source_security_group_id = module.backend_alb.sg_id
    security_group_id = module.catalogue.sg_id
}

#openvpn to catalogue ssh port 22
resource "aws_security_group_rule" "openvpn_catalogue_ssh" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    source_security_group_id = module.openvpn.sg_id
    security_group_id = module.catalogue.sg_id
}

#openvpn to catalogue http port directly on 8080
resource "aws_security_group_rule" "openvpn_catalogue_http" {
    type = "ingress"
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    source_security_group_id = module.openvpn.sg_id
    security_group_id = module.catalogue.sg_id
}

#bastion to catalogue on port 22
resource "aws_security_group_rule" "bastion_catalogue" {
    type = "ingress"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    source_security_group_id = module.bastion.sg_id
    security_group_id = module.catalogue.sg_id
}

# catalogue to mongodb on port 27017
resource "aws_security_group_rule" "catalogue_mongodb" {
    type = "ingress"
    from_port = 27017
    to_port = 27017
    protocol = "tcp"
    source_security_group_id = module.catalogue.sg_id
    security_group_id = module.mongodb.sg_id
}