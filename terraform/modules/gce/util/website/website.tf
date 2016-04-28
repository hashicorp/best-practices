#--------------------------------------------------------------
# This module is used to create an S3 bucket website
#--------------------------------------------------------------

variable "fqdn"          { }
variable "sub_domain"    { }
variable "managed_zone"  { }
variable "index_page"    { default = "index.html" }
variable "error_page"    { default = "error.html" }

resource "google_storage_bucket" "website" {
  name            = "website"
  predefined_acl  = "publicRead"
  force_destroy   = true

  website {
    main_page_suffix  = "${var.index_page}"
    not_found_page    = "${var.error_page}"
  }
}

resource "google_storage_bucket_object" "index" {
  name    = "index"
  bucket  = "${google_storage_bucket.website.self_link}"
  content =  <<EOF
You've reached the ${var.fqdn} index page
EOF
}

resource "google_storage_bucket_object" "error" {
  name    = "error"
  bucket  = "${google_storage_bucket.website.self_link}"
  content =  <<EOF
You've reached the ${var.fqdn} error page
EOF
}

resource "google_dns_record_set" "website" {
  managed_zone  = "${var.managed_zone}"
  name          = "${var.fqdn}"
  type          = "A"
  ttl           = 300
  rrdatas       = ["${google_storage_bucket.website.self_link}"]
}

output "bucket"         { value = "${google_storage_bucket.website.bucket}" }
output "fqdn"           { value = "${google_storage_bucket.website.fqdn}" }
output "bucket_uri"     { value = "${google_storage_bucket.website.self_link}"}
