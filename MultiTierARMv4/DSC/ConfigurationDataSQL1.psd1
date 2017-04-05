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
        SQLSourcePath		        = "F:\Source\SQLServer2014SP1-FullSlipstream-x64-ENU\"
        SQLFeatures					= "SQLENGINE,IS,SSMS,ADV_SSMS"
        SQLSvcAccount               = 'svcSQL'
        AdminAccount				= "Contoso\brw"  
        ClusterName					= "AOCluster" 
        ClusterIPAddress			= "10.0.1.10/24"
        AvailabilityGroupListenerIP = "10.0.1.100/255.255.255.0"
		InstanceName				= "MSSQLSERVER"
		StorageAccountSourcePath    = '\\saeastus2.file.core.windows.net\source'
		WindowsFeaturesSet          = "RSAT-Clustering-PowerShell","RSAT-AD-PowerShell","RSAT-Clustering-Mgmt","Failover-Clustering"
		#InstallerServiceAccount     = Get-Credential -UserName CORP\AutoSvc -Message "Credentials to Install SQL Server"

		RegistryKeyPresent          = @{ Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; 
                                         ValueName = 'DontUsePowerShellOnWinX';	ValueData = 0 ; ValueType = 'Dword'},

                                      @{ Key = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; 
                                         ValueName = 'TaskbarGlomLevel ';	ValueData = 1 ; ValueType = 'Dword'}

     },
    @{
        NodeName = 'SQL1'
        Role     = 'PrimaryClusterNode'
     }
 )
}
