locals {
  pw = { for k, v in random_password.all : k => v.result }
}
