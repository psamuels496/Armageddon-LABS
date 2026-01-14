resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.website.bucket
  key    = "index.html"
  source = "./lab-example/index.html"
  content_type = "text/html"

 
  etag = filemd5("./lab-example/index.html")
}

resource "aws_s3_object" "error" {
  bucket = aws_s3_bucket.website.bucket
  key    = "error.html"
  source = "./lab-example/error.html"
  content_type = "text/html"

 
  etag = filemd5("./lab-example/error.html")
}

resource "aws_s3_object" "image" {
  bucket = aws_s3_bucket.website.bucket
  key    = "image.jpg"
  source = "./lab-example/image.jpg"
  content_type = "image/jpeg"

 
  etag = filemd5("./lab-example/image.jpg")
}