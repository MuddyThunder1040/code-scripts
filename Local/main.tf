resource "local_file" "cpuinfofile" {
  filename = "${path.module}/cpuinfo.txt"
  content  = <<-EOT
    processor   : 0
    vendor_id   : GenuineIntel
    cpu family  : 6
    model       : 142
    model name  : Intel(R) Core(TM) i7-8550U CPU @ 1.80GHz
  EOT
}

data "local_file" "meminfo" {
  filename = "${path.module}/meminfo.txt"
  content  = "${file("${path.module}/JenkinsfileSoftwareCheck")}"
}
resource "local_sensitive_file" "name" {
  filename = "${path.module}/name.txt"
  content  = data.local_file.meminfo.content

}