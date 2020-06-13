provider "aws"{

region="ap-south-1"
profile="hemant"
}


resource "tls_private_key" "task1key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "keypair" {
  key_name   = "task1key"
  public_key = "${tls_private_key.task1key.public_key_openssh}"

  depends_on = [
    tls_private_key.task1key
  ]
}

resource "aws_security_group" "task1_sec_group" {
  name        = "task1_sec_group"
  description = "Allows SSH and HTTP"
  vpc_id      = "vpc-9ff7eaf7"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task1_sec_group"
  }
}

resource "aws_instance" "myin1"{

ami="ami-0447a12f28fddb066"
instance_type="t2.micro"
key_name=aws_key_pair.keypair.key_name
security_groups=["task1_sec_group"]

provisioner "remote-exec" {
    connection {
    agent    = "false"
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.task1key.private_key_pem}"
    host     = "${aws_instance.myin1.public_ip}"
  }
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

tags={
    Name="mytask1os"
}
}
output "az"{
        value=aws_instance.myin1.availability_zone
}

output "pubip"{
        value=aws_instance.myin1.public_ip
}

resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.myin1.availability_zone
  size              = 1

  tags = {
    Name = "myebs1"
  }
}
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.esb1.id
  instance_id = aws_instance.myin1.id
  force_detach=true
}

resource "null_resource" "pubip" {
  provisioner "local-exec" {
    command = "echo ${aws_instance.myin1.public_ip} > publicip.txt"
  }
}


resource "null_resource" "mounting" {
  depends_on = [
    aws_volume_attachment.ebs_att,
  ]

  connection {
    agent    = "false"
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.task1key.private_key_pem}"
    host     = "${aws_instance.myin1.public_ip}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdd",
      "sudo mount /dev/xvdh /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/whytedork/tera-ec2-auto.git  /var/www/html"
    ]
  }
}

resource "aws_s3_bucket" "task1-bucket" {
  bucket = "whytedork1"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags = {
    Name = "task1-bucket"
    Environment = "Dev"
  }
}
resource "aws_s3_bucket_object" "task1bucket_object" {
  key                    = "myimage"
  bucket                 = "${aws_s3_bucket.task1-bucket.id}"
  source                 = "/home/spidohemant/Desktop/tera_git/IMG_20181123_155343.jpg"
  acl="public-read"
}
resource "aws_cloudfront_distribution" "task1_cloudfront" {
    origin {
        domain_name = "whytedork1.s3.amazonaws.com"
        origin_id = "S3-whytedork1-id"


        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
    }

    enabled = true


    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-whytedork1-id"

        forwarded_values {
            query_string = false

            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }

    restrictions {
        geo_restriction {

            restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true
    }
}

resource "null_resource" "remote" {
  depends_on = [
    null_resource.mounting,
  ]


  provisioner "local-exec" {
    command = "google-chrome ${aws_instance.myin1.public_ip}"
  }
}
