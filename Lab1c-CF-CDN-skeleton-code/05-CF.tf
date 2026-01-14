
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name #  <bucket name>.<region>.s3.com
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
    origin_id                = local.origin_id
  }

  enabled             = true
  is_ipv6_enabled     = false
  comment             = "armageddon lab origin"
  default_root_object = "index.html"



  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.origin_id

    forwarded_values {
      query_string = false
# website.com/?588555sgrt
#website.com/

      cookies {
        forward = "none"
      }
    }
# http://<cf distro>.cloudfront.com -> https : //<cf distro>.cloudfront.com
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    #   locations        = ["US", "CA", "GB", "DE"]
    }
  }

  tags = {
    Environment = "production"
  }


custom_error_response {
  error_code = 404
  response_code = 404
  response_page_path = "/error.html"
}


  viewer_certificate {
    
    cloudfront_default_certificate = true
  }
}