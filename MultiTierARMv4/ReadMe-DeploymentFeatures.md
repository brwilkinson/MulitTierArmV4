# Key Features of this deployment

1. Setting up the Pre-Reqs. 

	See the PrereqsToDeploy directory to create a Certificate and also upload it to the KeyVault

	These create the wildcard certs and upload them to keyvault.
		
		These are used for the Web Server Certificates

		These self signed certs are automatically published in the MY, ROOT and CA stores.

	They also create secrets and upload them to KeyVault

		Optionally you can access the KeyVault at deploymenttime using the Parameter dialog
		
		* Note you do have to at least Create the KeyVault in the same region that you are deploying into.


	You also need WMF v5.0 or v5.1

		You need to add the required DSC resource modules with the following command

		Install-Module -Name xPSDesiredStateConfiguration,xActiveDirectory,xStorage,xPendingReboot,xComputerManagement

	You also need the Azure SDK and at least Visual Studio 2015 with update 3

		That is what makes the Cloud - Resource Group Deployments available via Visual Studio


2. Deployment (uniqueID for each deployment) = "Prefix" + "Environment" + "DeploymentID"

	DeploymentID is an Integer = 101
	Prefix is a unique user code = BRW
	Environment = Dev,Test,Prod

	Deployment = BRWDEV101

	* This ensures that each time you deploy you will never have any naming conflicts.
	* All resources are easy to identify.


3. JSON Parameter Allowed Values ensure that we have a validated set of values for any parameter

		E.g. vmStorageAccountType = "Standard_LRS","Standard_ZRS","Standard_GRS","Standard_RAGRS","Premium_LRS"
		E.g. vmDomainName         = "Contoso.com","AlpineSkiHouse.com","Fabrikam.com","TreyResearch.net"
		E.g. vmWindowsOSVersion   = "2008-R2-SP1","2012-Datacenter","2012-R2-Datacenter","2016-Datacenter"


4. Dynamically create resource names based on the unique Deployment *Build your naming standards into this process
	
	The Subnet is named: __snBRWDEV101-01__
	
		"[concat('sn', variables('Deployment'),'-01')]"

	---
	
	The Storage account is named: __sabrwdev101__

		"[toLower(concat('sa', variables('Deployment')))]"

	---
	
	The virtual machine DC1 is named: __vmBRWDEV101DC1__

		"[concat('vm', variables('Deployment'),'DC1')]"
	

5. Functions are used within the Template

	The Storage account is named: sabrwdev101 which is lower case, which is a requirement.

		"[toLower(concat('sa', variables('Deployment')))]"

	The public DNS is named: contosovmbrwdev101dc1, which is lower case, which is a requirement
	
		"DC1PublicDNSName": "[toLower(concat(variables('Domain'),variables('DC1vmName')))]"

	The full name will be: __contosovmbrwdevdc1.eastus.cloudapp.azure.com__, which has to be unique dns per region.


6. A subdeployment is called twice during the Deployment to adjust the DNS Servers setttings on the Subnet

	This nested template is part of the project and is automatically uploaded

	The Nested deployment takes some parameters:

	1. The DNS Servers
	2. The Deployment, since it uses this name to update the correct VNet/Subnet based on the naming standard

		E.g. __vnBRWDev101__/__snBRWDev101-01__


7. The AzureRM Modules that are required for this project are made available via the Azure SDK

	If you execute the following:
	
		Get-Module -ListAvailable -name azurerm*

	The modules should all be found under the following directory:

	Directory: __C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ResourceManager\AzureResourceManager__

	If you have any Azure Modules under the following directory, they have likely been manually installed
	or installed via the PowerShell Gallery. This can cause versioning issues and you should remove those modules.

	Directory: __C:\program files\WindowsPowershell\Modules__

	i.e. Use either the Azure SDK OR the PowerShell gallery, however not both.

8. Outputs, provides the Public DNS Name for the VM's


9. You can connect to Virtual Machine in Azure via it's Public IP Address or DNS name with MSTSC/RDP

	Only the FrontEnd Servers have a Public IP in this deployment.

	You can use these as a jump box to get to the other Virtual Machines using the Internal IP

	
10. You can Deploy the Full Template with all Tiers or simply deploy an individual Tier

	This is useful if you already have a VNet or if you already have a ActiveDirectory
	
	This is useful since you can initially deploy a small amount of MidTier, then go and add some later
	
	To Deploy all Tiers simply choose the following template
		
		0-azuredeploy-ALL.json
		
	Otherwise start with the template that you need, then proceed onto the next one
	
		1-azuredeploy-VNet.json
		2-azuredeploy-Directory.json
		3-azuredeploy-DataBase.json
		4-azuredeploy-MidTier.json
		5-azuredeploy-FrontEnd.json
		
	These templates work because they all share the exact same parameters and parameters file
	
		azuredeploy.parameters.json
		
	Also since the Parent Template calls the nested deployments if you use 0-azuredeploy-ALL.json
	
		The full set of Parameters and Values are read from the file or user input
		
		Then these are sent into the nested deployment via the following
		
			"parameters": "[deployment().properties.parameters]"
