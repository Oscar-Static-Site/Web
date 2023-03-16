variable "domain_name" {
    default = "oscarcorner.com"
    type = string
}

variable "bucket_name" {
    default = "oscarcorner.com"
    type = string
}
variable "zone" {
    default = "Z05080821D3KFPK0X4CL1"
    type = string
}
variable "common_tags" {
    default = {
        project = "oscarcorner.com"
    }
}
