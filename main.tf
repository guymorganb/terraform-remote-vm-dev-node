// We are selecting an IP address range for our VPC here in the CIDR Block: CIDR(Classless Inter-Domain Routing.)
/* 
Let's break down the CIDR notation and how it calculates the number of IP addresses:
CIDR Notation: It's an IP address followed by a slash (/) and a number. For example, in 10.0.0.0/16, 10.0.0.0 is the IP address and 16 after the slash is the subnet prefix length.

Private Address Space: Remember that VPCs use private IP address space. The available private IP address ranges are:
10.0.0.0 to 10.255.255.255 (10.0.0.0/8)
172.16.0.0 to 172.31.255.255 (172.16.0.0/12)
192.168.0.0 to 192.168.255.255 (192.168.0.0/16)

Subnet Prefix Length: This number (e.g., /16, /24) denotes how many bits of the IP address are fixed or "masked" for the network. The remaining bits are available for individual hosts (or IP addresses) within that network.
Calculating the Number of IP Addresses:
IP addresses are 32 bits long (for IPv4).
The number after the slash indicates how many of those bits are for the network prefix.
The remaining bits are for the hosts within that network.
The formula to determine the number of IP addresses within a CIDR block is 2^(32 - subnet prefix length).

For example:
/24 -> 2^(32-24) = 2^8 = 256 IP addresses.
/16 -> 2^(32-16) = 2^16 = 65,536 IP addresses.
Usage of IP Addresses: Do note that in AWS (and most networking contexts), the first and last IP addresses in any subnet are reserved (for the network address and broadcast address, respectively). So, in a /24 block, while you technically have 256 addresses, only 254 are usable for instances, databases, etc.

To give a clearer understanding, let's use the /24 example:
CIDR block: 10.0.0.0/24
IP address range: 10.0.0.0 to 10.0.0.255
Usable IP addresses: 10.0.0.1 to 10.0.0.254 (since 10.0.0.0 is the network address and 10.0.0.255 is the broadcast address) */
/* IP Address Range:

Starts at 10.123.0.0
Ends at 10.123.255.255
Usable IP Address Range:

Starts at 10.123.0.1
Ends at 10.123.255.254
So, for the CIDR block 10.123.0.0/16:

You have a total of 65,536 IP addresses. */
resource "aws_vpc" "vscodeCloud_vpc" {
  cidr_block           = "10.123.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}

resource "aws_subnet" "vscodeCloud_public_subnet" {
  vpc_id = aws_vpc.vscodeCloud_vpc.id // we will access the resource aws_vpc.vscodeCloud_vpc (<-remember this is a resource) specifically the .id attribute,
  // because we need the id for the subnet (use terraform show aws_vpc.vscodeCloud_vpc to find the id feild, which is for the subnet)
  // this method of referencing one resource from another is typically done through the .id attribute of the referenced resource.
  cidr_block              = "10.123.0.0/24" // this cidr block is on of the subnets inside the vcp range of ip addresses in the vpc resource
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"

  tags = {
    Name = "dev-public"
  }
}

resource "aws_internet_gateway" "vscodeCloud_internet_gateway" {
  vpc_id = aws_vpc.vscodeCloud_vpc.id

  tags = {
    Names = "dev-igw"
  }
}

resource "aws_route_table" "vscodeCloud_public_rt" {
  // we will use a routing resource for our routing table
  vpc_id = aws_vpc.vscodeCloud_vpc.id

  /* route {    example of inline route
    cidr_block = "10.0.1.0/24"
    gateway_id = aws_internet_gateway.example.id
  } */

  tags = {
    Names = "dev-public-rt"
  }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.vscodeCloud_public_rt.id
  destination_cidr_block = "0.0.0.0/0"                                          // this means all resources wil head through this route
  gateway_id             = aws_internet_gateway.vscodeCloud_internet_gateway.id // again pass the id to the gatway from the resource
}

resource "aws_route_table_association" "vscodeCloud_public_rt_assoc" {
  subnet_id      = aws_subnet.vscodeCloud_public_subnet.id
  route_table_id = aws_route_table.vscodeCloud_public_rt.id
}

resource "aws_security_group" "vscodeCloud_public_sg" {
  name        = "dev_sg"
  description = "dev security group"
  vpc_id      = aws_vpc.vscodeCloud_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["173.173.168.245/32"] // this is you ip address, only you are allowed to enter through the security group, you can add multiple ips
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          // allows all protocols, TCP/UDP and so on...
    cidr_blocks = ["0.0.0.0/0"] // allowing whatever/whoever is inside this subnet to access the open internet, in this case you...
  }
}

resource "aws_key_pair" "vscodeCloud_auth" {
  key_name   = "vscodeCloud_key"
  public_key = file("~/.ssh/vscodeCloudKey.pub")      // the file() function from terraform reads the file at this location
}

resource "aws_instance" "dev-node" {
  ami           = data.aws_ami.server_ami.id     // this is linking to the aws_ami in datasource.tf
  instance_type = "t2.micro"                     // this can be scaled up for a price
  subnet_id     = aws_subnet.vscodeCloud_public_subnet.id
  key_name = aws_key_pair.vscodeCloud_auth.id
  vpc_security_group_ids = [aws_security_group.vscodeCloud_public_sg.id]    // anytime theres a plural variable, it requires [].
  user_data = file("userdata.tpl")     // will extract the data from the userdata.tpl and bootstrap the EC@ instance with Docker so its ready to develope with.

  root_block_device {     // we are reszing the drive the free teir give you 16 for free, 8 is given by default
    volume_size = 16
  }
  /* cpu_options {
    core_count       = 2
    threads_per_core = 2
  } */
  tags = {
    Name = "dev-node"
  }
// terraform plan does not detect provisioners, so it wont add it to the state, we will need to trigger it another way
  provisioner "local-exec"{     // this provisioner will run inside the ec2 instance and pass our template.tpl file in and should allow us to run our vs code inside the virtual machine
// the templatefile function will allow string interpoolation -> ${} . WHich will pass the items from the vars after the comme into the file, this is what needs to happen for vscode to run inside the VM
      command = templatefile("${var.host_os}-ssh-config.tpl", { // var.host_os corresponds to the variable.tf so we can change variable on the fly and customize all this
          hostname = self.public_ip,
          user = "ubuntu",
          identityfile = "~/.ssh/vscodeCloudKey"
      })
      interpreter = var.host_os == "windows" ? ["Poweshell", "-Command"] : ["bash", "-c"]   
  }

}