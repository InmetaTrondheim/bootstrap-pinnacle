variable "bootstrap_script" {
  type        = string
  description = "The bootstrapping script to run to create the repo"
}
variable "repo_host" {
  type = string
  validation {
    condition     = contains(["github", "gitlab", "azuredevops"], var.repo_host)
    error_message = "Must be either github, gitlab, or azuredevops"
  }
  description = "The host of the repository to create"
}

resource "random_id" "temp_id" {
  byte_length = 8
}

locals {
  temp_dir = "/tmp/${random_id.temp_id.hex}"
}

resource "null_resource" "mkdir" {
  triggers = {
    bootstrap_script = var.bootstrap_script
  }

  provisioner "local-exec" {
    command     = "mkdir -p ${local.temp_dir} && git init ${local.temp_dir}"
    interpreter = ["/bin/sh", "-c"]
  }
}
resource "null_resource" "init_repository" {
  depends_on = [null_resource.mkdir]
  triggers = {
    bootstrap_script = var.bootstrap_script
  }

  provisioner "local-exec" {
    working_dir = local.temp_dir
    command     = var.bootstrap_script
    interpreter = ["/bin/sh", "-c"]
  }
}

output "initialized_folder_path" {
  depends_on = [null_resource.init_repository]
  value      = local.temp_dir
}
