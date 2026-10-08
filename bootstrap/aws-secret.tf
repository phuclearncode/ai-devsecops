resource "aws_secretsmanager_secret" "example" {
  name       = "bigid-client-secret"
  kms_key_id = aws_kms_key.mykey2.arn
}

resource "aws_kms_key" "mykey2" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}