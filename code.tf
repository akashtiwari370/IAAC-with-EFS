provider "aws" {
  region  = "ap-south-1"
  profile = "your-profile"
}

###################################

resource "tls_private_key" "tls_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}



resource "local_file" "key-file" {
  content  = tls_private_key.tls_key.private_key_pem
  filename = "my-key.pem"
  file_permission = 0400

  depends_on = [
    tls_private_key.tls_key
  ]
}

#########################################


resource "aws_key_pair" "generated_key" {
  key_name   = "my-key"
  public_key = tls_private_key.tls_key.public_key_openssh
   
 depends_on = [
    tls_private_key.tls_key
  ]
}

############################################


resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-a7c3decf"

 ingress {
    description = "SSH Rule"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "HTTP Rule"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 egress {
	from_port  =  0
	to_port   =  0
	protocol   =   "-1"
	cidr_blocks =  [ "0.0.0.0/0" ]
	
}
 
  tags = {
    Name = "allow_tls"
  }
}

############################################


resource "aws_instance" "web" {
  ami             = "ami-0447a12f28fddb066"
  instance_type   = "t2.micro"
  key_name        = "my-key"
  security_groups = ["allow_tls"]


  
  tags = {
    Name = "Infraos"
   
  }

 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key   =   file("C:/users/Aki/Desktop/terra/task2/my-key.pem")
    host     = aws_instance.web.public_ip

     
  }


provisioner "remote-exec" {
    inline = [
       "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
     
    ]
  }
}

######################################################



resource "aws_efs_file_system" "foo" {
  creation_token = "first"

  tags = {
    Name = "MyEFS"
  }
}



#################################################

resource "aws_efs_mount_target" "alpha" {
  file_system_id =  aws_efs_file_system.foo.id
  subnet_id      =  "subnet-09fcadb36f6db0bc5"
}

#####################################################

resource "null_resource"  "nullres" {
            provisioner "remote-exec" {
    inline = [
         "sudo yum -y install nfs-utils",
         "sudo mount -t nfs -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.foo.id}:/   /var/www/html",
        "sudo su -c \"echo '${aws_efs_file_system.foo.id}:/ /var/www/html nfs4 defaults,vers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0' >> /etc/fstab\""
     
    ]
  }
}

################################################


resource "aws_s3_bucket" "terra-bucket" {
  bucket = "git-code-for-terra"
  acl    = "public-read"

	 provisioner "local-exec" {
		command  =  "git clone https://github.com/akashtiwari370/cloud.git  terraform"
	}
	
	tags =  {
		Name = "terras3"
		Environment  =  "Production"
	}
versioning {
    enabled  =   true
}


}

#######################################################


resource "aws_s3_bucket_object" "bucket-push" {
  bucket = aws_s3_bucket.terra-bucket.bucket
  key   =   "1.jpg"
  source = "terraform/1.jpg"
  acl    = "public-read"
}

resource "aws_s3_bucket_object" "bucket-push2" {
  bucket = aws_s3_bucket.terra-bucket.bucket
  key   =   "2.jpg"
  source = "terraform/2.jpg"
  acl    = "public-read"
}

resource "aws_s3_bucket_object" "bucket-push3" {
  bucket = aws_s3_bucket.terra-bucket.bucket
  key   =   "3.jpg"
  source = "terraform/3.jpg"
  acl    = "public-read"
}






// ###################################################




resource "aws_cloudfront_distribution" "s3-web-distribution" {
  origin {
    domain_name = aws_s3_bucket.terra-bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.terra-bucket.id

	custom_origin_config {
		http_port  =  80
		https_port  =  80
		origin_protocol_policy  = "match-viewer"
		origin_ssl_protocols  =  [ "TLSv1", "TLSv1.1", "TLSv1.2" ]
	}
 
  }


  enabled             = true
  is_ipv6_enabled     = true


	


  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.terra-bucket.id


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


  tags = {
    Name        = "Terra-Distribution"
    Environment = "Production"
  }


  viewer_certificate {
    cloudfront_default_certificate = true
  }


  depends_on = [
    aws_s3_bucket.terra-bucket
  ]

 




provisioner "remote-exec" {
    inline = [
      "sudo bash -c 'echo export url=${aws_s3_bucket.terra-bucket.bucket_domain_name} >> /etc/apache2/envvars'",
      "sudo sysytemctl restart apache2"
    ]
  }

}

#####################################################################################################


resource "null_resource"  "nullcall" {
	provisioner "local-exec" {
		command = "start chrome  ${aws_instance.web.public_ip}"
		}
	}

###############################
  
