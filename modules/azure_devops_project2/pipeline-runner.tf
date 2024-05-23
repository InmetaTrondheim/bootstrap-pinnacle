locals {
  command_parts = [
    "sudo snap install terraform --classic",
    "curl -fsSL https://get.docker.com -o get-docker.sh",
    "sudo sh get-docker.sh",
    "sudo systemctl enable docker",
    "sudo systemctl start docker",
    "sudo usermod -aG docker adminuser",  // Add adminuser to docker group
    "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
  ]

  command_parts_nr2 = [
    "cd",
    "az extension add --name azure-devops",
    "wget https://vstsagentpackage.azureedge.net/agent/3.240.0/vsts-agent-linux-x64-3.240.0.tar.gz",

    "tar zxvf vsts-agent-linux-x64-3.240.0.tar.gz",
    "sudo ./bin/installdependencies.sh",
    "./config.sh --unattended --url ${data.env_var.AZDO_ORG_SERVICE_URL.value} --auth pat --token ${data.env_var.AZDO_PERSONAL_ACCESS_TOKEN.value} --pool ${azuredevops_agent_pool.pool.name} --agent $(hostname)-${formatdate("YY--MM--DD-hh-mm", timestamp())}",
    "sudo ./svc.sh install",
    "sudo ./svc.sh start"
  ]

  full_command = concat(local.command_parts, ["sudo -i -u adminuser bash -c '${join(" && ", local.command_parts_nr2)}'"])

}

resource "azurerm_virtual_network" "vnet" {
  name                = "myVNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "mySubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# uncomment block to allow ssh access to machine
resource "azurerm_public_ip" "agent_public_ip" {
  name                = "agentPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "agent_nsg" {
  name                = "agentNSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "agent_nic_nsg" {
  network_interface_id      = azurerm_network_interface.agent_nic.id
  network_security_group_id = azurerm_network_security_group.agent_nsg.id
}
# ---

resource "azurerm_network_interface" "agent_nic" {
  name                = "agentNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.agent_public_ip.id
  }
}

resource "azuredevops_agent_pool" "pool" {
  name = "GenesisPool-${var.project_name}"
  auto_provision = true
}

resource "azurerm_linux_virtual_machine" "agent_vm" {
  name                = "pipeline-runner"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.agent_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  disable_password_authentication = true
}

resource "azurerm_virtual_machine_extension" "agent_setup" { 
  depends_on           = [azuredevops_project.project, azuredevops_agent_pool.pool]
  name                 = "configure-devops-agent"
  virtual_machine_id   = azurerm_linux_virtual_machine.agent_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = jsonencode({ commandToExecute = join(" && ", local.full_command) })
}

