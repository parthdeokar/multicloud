

provider "aws" {
  region = "ap-south-1"
  profile="parth"
}



//key-Pair Creation
resource "aws_key_pair" "ec2_terra_key" {
  key_name   = "ec2_terra_key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCqZnWQLhs8bv1ksCWHKHU8ndKNfY/fuo/r0kjr5F1xf33kRe5JAEIxvK1IYL+2SZmZ8hh+qd/X+oXU82S588JuIJwUFXBdY1aFmqNldFAqIYgd3tEgaohgXR2uXBkk+g9l+b+gRV/ftP/JBuohhS2HczJ4oWR0TxWqGSzj3PLy9LS+87mWbscC3kJ4gLwRjcpmbLAX0U5AYYgGpytcuZ8hFSu9T7L8UEu3Aeq0ANDYzb8uAHuLcUTNZGITR01aTKbvIU8lI6/cwhertigPlEXhPg/nK7K04BIGh1hhbRjcVV7EfJczKOjOfVT3zBZCrEAckHyNzQtVenZbSZgBTmhcYrARA1px4ZP+21T4xYycIT25XW7x/lGEiFMO52AzEybWMYslW+OugaCjvAHX7QxANvPJYrnksCc3L2cLRz/n+a+Q+731vjJ20uYTV+gsNGCUoo/IZr1g4IYUetyHFwGNGfwoXEMoG+rLAg82nKLR1VqqJKtD892y/4rv/M+Xkdc= deokar@PARTH"
}



//Security Group
resource "aws_security_group" "SG_allow_http_ssh" {
  name        = "SG_allow_http_ssh"

  ingress {
    description ="http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description ="ssh"
    from_port   = 22
    to_port        = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "SG_allow_http_and_ssh"
  }
}



//creating Ec2 instances

resource "aws_instance"  "my_os_1" {
  ami           	= "ami-0447a12f28fddb066"
  instance_type 	= "t2.micro"
  key_name	= "ec2_terra_key"
  security_groups	= ["SG_allow_http_ssh"]
  tags = {
         Name = "first_terraform_os"
    }

   connection {
      type     = "ssh"
      user     = "ec2-user"
      private_key = file("C:/Users/Deokar/Desktop/terra/project/mykey.pem")                       
      host     = aws_instance.my_os_1.public_ip
    }
 provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd"]
  }
depends_on=[
 aws_key_pair.ec2_terra_key,aws_security_group.SG_allow_http_ssh,
]
}
 output  "myosip"{
       value = aws_instance.my_os_1.public_ip
}


//EBS creation 
resource "aws_ebs_volume" "EBS_1" {
  availability_zone = aws_instance.my_os_1.availability_zone
  size              = 1
  tags = {
    Name = "EBS_1"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${ aws_ebs_volume.EBS_1.id }"
  instance_id = "${ aws_instance.my_os_1.id }"
  force_detach=true
depends_on = [
    aws_ebs_volume.EBS_1,
  ]
}



//ebs formate and mount 
resource "null_resource" "null_1"{
connection {
      type     = "ssh"
      user     = "ec2-user"
      private_key = file("C:/Users/Deokar/Desktop/terra/project/mykey.pem")                       
      host     = aws_instance.my_os_1.public_ip
    }

provisioner "remote-exec" {
    inline = [
	"sudo mkfs.ext4  /dev/xvdh",
	"sudo mount /dev/xvdh /var/www/html",
	"sudo rm -rf /var/www/html/*",
	"sudo git clone https://github.com/parthdeokar/multicloud.git  /var/www/html/"
	]
  }
   depends_on=[
    aws_volume_attachment.ebs_att,
  ]
}

//bucket Creation 

resource "aws_s3_bucket" "parth_s3_bucket" {
   bucket = "mybucket987654321"
   acl    = "public-read"
   region   = "ap-south-1"

  tags = {
    Name  = "mybucket987654321"
  }
}

//Adding 0bject to s3 bucket

resource "aws_s3_bucket_object" "my_s3_object1" {
	  bucket = "${aws_s3_bucket.parth_s3_bucket.id}"
  	key    = "new_image1"
  	source = "C:/Users/Deokar/Desktop/terra/project/parth.jpg"
	acl        = "public-read"
depends_on=[
    aws_s3_bucket.parth_s3_bucket,
  ]
}


output  "myosip2"{
       value = aws_s3_bucket.parth_s3_bucket.id
}

//Creating CloudFrount Distribution with origin as S3
locals {
  s3_origin_id = "${aws_s3_bucket.parth_s3_bucket.id}"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
depends_on=[
aws_s3_bucket_object.my_s3_object1,
]
  origin {
    domain_name = "${aws_s3_bucket.parth_s3_bucket.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"
  }

 enabled = true
default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
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

resource "null_resource" "null_2"{
connection {
      type     = "ssh"
      user     = "ec2-user"
      private_key = file("C:/Users/Deokar/Desktop/terra/project/mykey.pem")                       
      host     = aws_instance.my_os_1.public_ip
}


provisioner "remote-exec" {
    inline = [
	"sudo su <<END",
	"echo \"<img src ='http://$(aws_cloudfront_distribution.s3_distribution.domain_name)/$(aws_s3_bucket_object.my_s3_object1.key)' hight='500' width='450'>\">> /var/www/html/index.html",
	"END"
	]
  }
}


