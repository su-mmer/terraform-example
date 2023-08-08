terraform {
  backend "s3" {
    bucket = "terraform-up-hh"  # 이전에 생성한 S3 이름
    key = "stage/data-stores/mysql/terraform.ftstate"  # tfstate를 저장할 S3 버킷 내 경로
    region = "ap-northeast-2"

    dynamodb_table = "terraform-up-and-lock"  # 이전에 생성한 dynamoDB 테이블 이름
    encrypt = true  # 암호화 활성화 => S3 버킷 암호화 + backend 암호화로 이중 설정
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_db_instance" "example" {
  identifier_prefix   = "terraform-up-and-running"
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.t2.micro"
  skip_final_snapshot = true

  db_name             = var.db_name
  username = var.db_username
  password = var.db_password
}