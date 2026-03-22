output "ec2_public_ip" {
  description = "Public IP of the deployed EC2 instance"
  value       = aws_instance.devops_ec2.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.devops_ec2.public_dns
}

output "app_url" {
  description = "URL to access the deployed app"
  value       = "http://${aws_instance.devops_ec2.public_ip}"
}
