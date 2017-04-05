#
# ConfigurationDataSQL.psd1
#


@{ 
AllNodes = @( 
    @{ 
        NodeName					= "*" 
		PSDscAllowDomainUser		= $true
		PSDscAllowPlainTextPassword = $true
        NETPath						= "F:\source\sxs"
        SQLSourcePath		        = "F:\Source\SQLServer2016-x64-ENU\"
        SQLFeatures					= "SQLENGINE,IS,SSMS,ADV_SSMS"
        SQLSvcAccount               = 'svcSQL'
        AdminAccount				= "Contoso\BRW"  
        ClusterName					= "TECluster" 
		FileShareWitnessPath        = '\\SQLWitness1\SQLWitness'
        ClusterIPAddress			= "10.0.1.10/24"
		InstanceName				= "MSSQLSERVER"
		StorageAccountSourcePath    = '\\saeastus2.file.core.windows.net\source'
		WindowsFeaturesSet          = "RSAT-Clustering-PowerShell","RSAT-AD-PowerShell","RSAT-Clustering-Mgmt","Failover-Clustering"
		#InstallerServiceAccount     = Get-Credential -UserName CORP\AutoSvc -Message "Credentials to Install SQL Server"
     },
    @{
        NodeName = 'Localhost'
        Role     = 'ReplicaServerNode'
     }
 )
}


