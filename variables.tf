// these values wont be used if they are defined in .tfvars, because .tfvars takes precedence
variable "host_os"{
    type = string
    default = "mac"     // by adding default this value does not require dynamic input
}