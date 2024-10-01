resource "aws_ssm_parameter" "keystore_content" {
  name        = "/hive-gateway/keystore-content"
  description = "Keystore content for hive-gateway"
  type        = "SecureString"
  value       = file(var.keystore_name)
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "keystore_name" {
  name        = "/hive-gateway/keystore-name"
  description = "Keystore filename for hive-gateway"
  type        = "String"
  value       = var.keystore_name
  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "keystore_pw" {
  name        = "/hive-gateway/keystore-pw"
  description = "Keystore password for hive-gateway"
  type        = "SecureString"
  value       = var.keystore_pw
  lifecycle {
    ignore_changes = [value]
  }
}
