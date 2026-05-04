provider "aws" {
  access_key = "test"
  secret_key = "test"
  region     = "us-east-1"

  s3_use_path_style = true

  endpoints {
    dynamodb = "http://localhost:4566"
    s3 = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
  cloud {
    organization = "oiasis-org"

    workspaces {
      name = "homelab-tf"
    }
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

resource "aws_dynamodb_table" "localstack_table" {
  name         = "localstack-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}
