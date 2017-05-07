
# MulitTierArmV4
Azure Resource Group Deployment - MultiTier Environment

- [Template Features and Pre-requisites](./MultiTierARMv4/ReadMe-DeploymentFeatures.md "MultiTierArmV4 Deployment Features")

	To Deploy all Tiers simply choose the following template
		
		0-azuredeploy-ALL.json
		
	Otherwise start with the template that you need, then proceed onto the next one
	
		1-azuredeploy-VNet.json
		2-azuredeploy-Directory.json
		3-azuredeploy-DataBase.json
		4-azuredeploy-VMPublic.json
		5-azuredeploy-VMPrivate.json
		6-azuredeploy-ILBalancer.json
		7-azuredeploy-WebAppFirewall.json

	Define the servers you want to deploy using a table in JSON, so you can create as many as you like
	Each server has a role that puts it in an availabilityset and also uses the role to run the DSC configuration
	All VM's used manageddisks
```
    "AppRoles": [
        {"Role" : "WebFE" },
        {"Role" : "WebMT" }
    ],

    "AppServers": [
            {"VMName":"WebFE01","Role":"WebFE","VMSize":"Standard_DS4","Subnet":"FE", "StorageType" : "Standard_LRS"},
            {"VMName":"WebFE02","Role":"WebFE","VMSize":"Standard_DS4","Subnet":"FE", "StorageType" : "Standard_LRS"},
            
            {"VMName":"WebMT01","Role":"WebMT","VMSize":"Standard_DS12","Subnet":"MT", "StorageType" : "Standard_LRS"},
            {"VMName":"WebMT02","Role":"WebMT","VMSize":"Standard_DS12","Subnet":"MT", "StorageType" : "Standard_LRS"}
      ],
```
