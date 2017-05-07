
# MulitTierArmV4
Azure Resource Group Deployment - MultiTier Environment

- [Template Features and Pre-requisites](./MultiTierARMv4/ReadMe-DeploymentFeatures.md "MultiTierArmV4 Deployment Features")

	To Deploy all Tiers simply choose the following template
		
		0-azuredeploy-ALL.json
		
	Otherwise start with the template that you need, then proceed onto the next one
	
		1-azuredeploy-VNet.json
		2-azuredeploy-Directory.json
		3-azuredeploy-DataBase.json
		4-azuredeploy-MidTier.json
		5-azuredeploy-FrontEnd.json
		6-azuredeploy-ILBalancer.json
		7-azuredeploy-WebAppFirewall.json
