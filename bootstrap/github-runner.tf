variable "runner_instance_type" {
  type    = string
  default = "t3.small"
}

# Fine-grained PAT (repo "Administration: read & write") used to register runners.
# Terraform only creates the container; put the value in with the CLI so it never lands in state.
resource "aws_secretsmanager_secret" "github_runner_pat" {
  name       = "github-runner-pat"
  kms_key_id = aws_kms_key.mykey2.arn
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Egress only: the runner polls GitHub, nothing needs to reach it. Access via SSM Session Manager.
resource "aws_security_group" "github_runner" {
  name   = "github-runner"
  vpc_id = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_runner" {
  name               = "github-runner-ec2"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "github_runner_ssm" {
  role       = aws_iam_role.github_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# The instance itself can only read the registration PAT. Jobs get AWS access through OIDC.
data "aws_iam_policy_document" "github_runner_pat" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.github_runner_pat.arn]
  }
  statement {
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.mykey2.arn]
  }
}

resource "aws_iam_role_policy" "github_runner_pat" {
  name   = "read-runner-pat"
  role   = aws_iam_role.github_runner.id
  policy = data.aws_iam_policy_document.github_runner_pat.json
}

resource "aws_iam_instance_profile" "github_runner" {
  name = "github-runner-ec2"
  role = aws_iam_role.github_runner.name
}

resource "aws_instance" "github_runner" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.runner_instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.github_runner.id]
  iam_instance_profile        = aws_iam_instance_profile.github_runner.name
  associate_public_ip_address = true # default VPC has no NAT

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/templates/runner-user-data.sh.tftpl", {
    region      = "ap-southeast-1"
    secret_id   = aws_secretsmanager_secret.github_runner_pat.name
    github_repo = "${var.github_owner}/${var.github_repo}"
    labels      = "aws,ec2"
  })

  # Don't re-create the runner every time Amazon publishes a new AMI.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = {
    Name = "github-runner"
  }
}
