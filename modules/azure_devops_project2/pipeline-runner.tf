

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

resource "azurerm_network_interface" "agent_nic" {
  name                = "agentNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}


resource "azuredevops_agent_pool" "pool" {
  name = "GenesisPool"
}
resource "azurerm_linux_virtual_machine" "agent_vm" {
  name                = "example-vm"
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
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  disable_password_authentication = true
}


resource "azurerm_virtual_machine_extension" "agent_setup" {
  name                 = "configure-devops-agent"
  virtual_machine_id   = azurerm_linux_virtual_machine.agent_vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
    {
      "commandToExecute": "useradd -m -s /bin/bash azureagent && echo azureagent:Azure123! | chpasswd && wget https://vstsagentpackage.azureedge.net/agent/2.170.1/vsts-agent-linux-x64-2.170.1.tar.gz && tar zxvf vsts-agent-linux-x64-2.170.1.tar.gz -C /home/azureagent && sudo -i -u azureagent bash -c 'cd ~/ && ./config.sh --unattended --url ${data.env_var.AZDO_ORG_SERVICE_URL.value} --auth pat --token ${data.env_var.AZDO_PERSONAL_ACCESS_TOKEN.value} --pool ${azuredevops_agent_pool.pool.name} --agent $(hostname) && ./run.sh'"
    }
SETTINGS
	# settings = jsonencode({
	#    commandToExecute = join(" && ", [
	#      "sudo useradd -m -s /bin/bash azureagent",
	#      "echo azureagent:Azure123! | sudo chpasswd",
	#      "wget https://vstsagentpackage.azureedge.net/agent/2.170.1/vsts-agent-linux-x64-2.170.1.tar.gz",
	#      "tar zxvf vsts-agent-linux-x64-2.170.1.tar.gz -C /home/azureagent",
	#      "sudo -i -u azureagent bash -c 'cd ~/ && ./config.sh --unattended --url ${data.env_var.AZDO_ORG_SERVICE_URL.value} --auth pat --token ${data.env_var.AZDO_PERSONAL_ACCESS_TOKEN.value} --pool ${azuredevops_agent_pool.pool.name} --agent $(hostname) && ./run.sh'"
	#    ])
	#  })
}

