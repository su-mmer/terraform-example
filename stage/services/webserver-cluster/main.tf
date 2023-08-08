# aws 인증
provider "aws" {
  profile = "hh"
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Name = "terraform-example"
    }
  }
}

# 서버 생성
# resource "aws_instance" "example" {
#   ami = "ami-0c9c942bd7bf113a2"  // 22.04 Ubuntu LTS
#   instance_type = "t2.micro"
#   vpc_security_group_ids = [aws_security_group.instance_sg.id]

#   user_data = <<-EOF
#               #!/bin/bash
#               echo "Hello, World!" > index.html
#               nohup busybox httpd -f -p ${var.server_port} &
#               EOF
# }

# file을 렌더링한 결과를 template_file에 저장함
data "template_file" "user_data" {
  template = file("user-data.sh")

  vars = {
    server_port = var.server_port
    db_address = data.terraform_remote_state.db.outputs.address
    db_port = data.terraform_remote_state.db.outputs.port
  }
}

data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "ap-northeast-2"
  }
}

# Auto Scaling group을 위한 instance 시작 구성 파일
resource "aws_launch_configuration" "example" { // ASG를 위한 시작 구성
  image_id = "ami-0c9c942bd7bf113a2" // 22.04 Ubuntu LTS
  instance_type = "t2.micro"

  security_groups = [aws_security_group.instance_sg.id]  // SG id 연결

  // 시작 시 실행될 스크립트, 초기 시작 한 번만 진행되기 때문에 변경되면 인스턴스 삭제 후 다시 생성됨
  user_data = data.template_file.user_data.rendered

  lifecycle {
    create_before_destroy = true  // 교체 리소스를 먼저 생성하고 기존 리소스 삭제
  }
}

# 보안 그룹 생성
resource "aws_security_group" "instance_sg" {
  name = "terraform-example-instance"

  ingress {  // inbound
    from_port = var.server_port  // 시작 번호
    to_port = var.server_port  // 마지막 번호
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# default VPC 데이터
data "aws_vpc" "defaultVPC" {
  default = true  // default VPC 가져오도록 함
}

# default subnet을 여러개 불러옴(aws_subent은 한 개만)
data "aws_subnets" "defaultSubnet" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.defaultVPC.id]  // vpc-id가 해당 값인 서브넷을 전부 불러옴
    }
}

# Auto Scaling Group 생성
resource "aws_autoscaling_group" "example" {  // ASG 생성
  launch_configuration = aws_launch_configuration.example.name
  # vpc_zone_identifier = data.aws_subnets.defaultSubnet.ids  // ASG를 시작할 서브넷 ID 목록, AZ를 자동으로 정해줌
  availability_zones = ["ap-northeast-2a","ap-northeast-2c"]

  target_group_arns = [aws_lb_target_group.asg.arn]  // 타겟그룹 연결
  health_check_type = "ELB"

  min_size = 2  // 초기 시작 2개
  max_size = 10  // 최대 10까지 확장 가능
}

# ALB 생성
resource "aws_lb" "example" {
  name = "terraform-asg-example"
  load_balancer_type = "application"
  subnets = data.aws_subnets.defaultSubnet.ids  // 생성할 subnet 지정
  security_groups = [aws_security_group.alb.id]  // ALB에 통신을 허락할 보안그룹 연결
}

# ALB Lister 생성
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn  // 생성한 로드밸런서
  port = 80
  protocol = "HTTP"

  default_action {  // 기본값으로 404 페이지오류를 반환하도록 설정
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404:page not found"
      status_code  = 404
    }
  }
}

# ALB를 위한 보안그룹 생성
resource "aws_security_group" "alb" {
  name = "terraform-example-alb"

  ingress {  // inbound 80포트만 허용
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {  // outbound 모든 포트 허용
    from_port = 0
    to_port = 0
    protocol = "-1"  // 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB 타겟 그룹
resource "aws_lb_target_group" "asg" {
  name = "terraform-asg-example"
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_vpc.defaultVPC.id

  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"  // matcher와 일치하는 응답을 반환하는 경우에만 인스턴스를 정상으로 간주
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }
}

# aws lb listener rule
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100
  
  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}
