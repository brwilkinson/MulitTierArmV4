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
        SourcePath					= "F:\Source\SQL2014\"
        AdminAccount				= "Corp\user1"  
        ClusterName					= "DevCluster" 
        ClusterIPAddress			= "10.0.75.199/24"
		InstanceName				= "MSSQLSERVER"
        Features					= "SQLENGINE,IS,SSMS,ADV_SSMS"
		Role						= "SecondaryClusterNode"
		StorageAccountSourcePath   = '\\saeastus2.file.core.windows.net\source'
		WindowsFeaturesSet          = "RSAT-Clustering-PowerShell","RSAT-AD-PowerShell","RSAT-Clustering-Mgmt","Failover-Clustering"
		#InstallerServiceAccount     = Get-Credential -UserName CORP\AutoSvc -Message "Credentials to Install SQL Server"
     },
    @{ 
        NodeName					= "SQL1" 
		Role						= "PrimaryClusterNode"
	}
 )
}
