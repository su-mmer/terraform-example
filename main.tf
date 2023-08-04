provider "aws" {
  profile = "hh"
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Name        = "terraform-example"
    }
  }
}

resource "aws_instance" "example" {
    ami = "ami-0c9c942bd7bf113a2"  // 22.04 Ubuntu LTS
    instance_type = "t2.micro"
}