# It's a good security practice to have databases in private subnets, but
# that means they cannot be accessed from the public internet in cases of
# emergency. A bastion host, however, can access all the resources in the VPC
# and is simultaneously accessible from the public internet.
#
# From Wikipedia:
# > A bastion host is a special purpose computer on a network specifically designed
# > and configured to withstand attacks.
# > The computer generally hosts a single application,
# > for example a proxy server, and all other services are
# > removed or limited to reduce the threat to the computer.
# > It is hardened in this manner primarily due to its location and purpose,
# > which is either on the outside of a firewall or in a demilitarized zone (DMZ)
# > and usually involves access from untrusted networks or computers.
#
# The security of the private resources depends on the security of the bastion host.
# Access should be restricted as much as possible, with only the SSH port open.
# Anyone with access to the private key of the bastion's instance can log in.
#
# See: https://www.davidbegin.com/creating-an-aws-bastion-host-with-terraform/
#
# In case you want to connect to a private resource via the bastion instance,
# see: https://medium.com/@carlos.ribeiro/connecting-on-rds-server-that-is-not-publicly-accessible-1aee9e43b870

# Find the latest Ubuntu 16.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Create the EC2 instance with Ubuntu as the operating system
resource "aws_instance" "bastion_instance" {
  ami           = "${data.aws_ami.ubuntu.id}"                # Ubuntu 16.04 LTS, eligible for free tier
  key_name      = "${aws_key_pair.bastion_ssh_key.key_name}"
  instance_type = "t2.micro"                                 # t2.micro eligible for free tier

  vpc_security_group_ids = [
    "${aws_security_group.bastion_security_group.id}",
    "${aws_security_group.access_db_security_group.id}",
  ]

  subnet_id                   = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = true

  tags = "${local.common_tags}"
}

resource "aws_security_group" "bastion_security_group" {
  name   = "Bastion security group"
  vpc_id = "${module.vpc.vpc_id}"

  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22

    # 0.0.0.0/0 opens the EC2 instance to the public internet, but
    # only those with access to the private SSH key defined below can actually
    # connect.
    # For tighter security, you can restrict to specific IPs by replacing
    # "0.0.0.0/0" with "<IP address>/32".
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outgoing traffic from the EC2 instance is allowed.
  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "bastion_ssh_key" {
  key_name   = "bastion-ssh-key-${var.stage}"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+4LID5JUM8x6M2vaa3R2K3ga26iYl9lc9z0+y2W3ANlzKXmqesFkYIwIWWM0J1Y5OgJGHrpw96xGynlNG0GLnvtbKFwX3wTo6d0WDRqnBx3blsJ7SI/Yd2d3VmVQQMB/tZG2OGnTDAhpCGdcHQfYzfNIEPf2fBpAhXYMRLjEmFxgyaqzrM0ZGBhKiWatO38V6mz1aeOdQYdinximeeMgr8rsq74wrVYup4p3tBAMTVfiQu6qNFX0UfaHkkYDepy5WT7XneFULKcUONQIp5Gzpf7l3Ay718ug8y7CKvp810TvZem2Z0x/20hMeixv4lvUaemt1/xLvwu9629A/0TQt f@f-X580VD"
}

output "bastion_public_ip" {
  value = "${aws_instance.bastion_instance.public_ip}"
}
