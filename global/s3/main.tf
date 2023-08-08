provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.bucket_name
  force_destroy = true  # 실수로 삭제 방지

#   lifecycle {
#     prevent_destroy = true
#   }
#   versioning {
#     enabled = true
#   }

#   server_side_encryption_configuration {
#     rule {
#         apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#     }
#   }
}

# 버전 관리 활성화
resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 서버 측 암호화 활성화
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"  # DynamoDB를 잠금에 사용하기 위함

  attribute {
    name = "LockID"
    type = "S"
  }
}