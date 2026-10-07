# latest Amazon Linux 2023 AMI for this region, looked up instead of hard-coding an AMI ID
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]

  # installs nginx on first boot and writes a page showing where it's running
  user_data = <<-SCRIPT
    #!/bin/bash
    dnf install -y nginx
    TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
    md() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/$1; }
    cat > /usr/share/nginx/html/index.html <<HTML
    <html><body style="font-family:sans-serif;margin:40px">
    <h1>Session 19 - deployed with Terraform</h1>
    <p>Instance: $(md instance-id) ($(md instance-type))</p>
    <p>Availability zone: $(md placement/availability-zone)</p>
    <p>Private IP: $(md local-ipv4)</p>
    <p>Owner: ${var.owner}</p>
    </body></html>
    HTML
    systemctl enable --now nginx
  SCRIPT

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  # explicit dependency: user_data needs the internet route to exist before boot,
  # but nothing in this resource references the route table, so Terraform can't infer it
  depends_on = [aws_route_table_association.public]

  tags = { Name = "${var.project}-web" }
}
