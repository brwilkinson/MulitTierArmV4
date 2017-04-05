Configuration Main
{
Param ( 
		[String]$DomainName = 'contoso.com',
		[PSCredential]$AdminCreds,
		[Int]$RetryCount = 20,
		[Int]$RetryIntervalSec = 120,
        [String]$ThumbPrint = '606295CAE217319DC730F8F16D52C6BEF636047B',
		[String]$StorageAccountKeySource
		)

Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -ModuleName xComputerManagement
Import-DscResource -ModuleName xActiveDirectory
Import-DscResource -ModuleName xStorage
Import-DscResource -ModuleName xPendingReboot
Import-DscResource -ModuleName xWebAdministration
Import-DscResource -ModuleName xSQLServer
Import-DscResource -ModuleName xFailoverCluster
Import-DscResource -ModuleName xnetworking

$NetBios = $(($DomainName -split '\.')[0])
[PSCredential]$DomainCreds = [PSCredential]::New( $NetBios + '\' + $(($AdminCreds.UserName -split '\\')[-1]), $AdminCreds.Password )

Node $AllNodes.NodeName
{
    Write-Warning -Message "AllNodes"
    Write-Verbose -Message "Node is: [$($Node.NodeName)]" -Verbose
    Write-Verbose -Message "NetBios is: [$NetBios]" -Verbose
    Write-Verbose -Message "DomainName is: [$DomainName]" -Verbose
    $SQLSvcAccount = $NetBios + '\' + $Node.SQLSvcAccount
    Write-warning "user is: $SQLSvcAccount"
    [PSCredential]$SQLSvcAccountCreds = [PSCredential]::New( $SQLSvcAccount , $AdminCreds.Password)
    write-warning -Message $SQLSvcAccountCreds.UserName
    #write-warning -Message $SQLSvcAccountCreds.GetNetworkCredential().password

    if ($Node.WindowsFeaturesSet)
    {
        $Node.WindowsFeaturesSet | foreach {
            Write-Verbose -Message $_ -Verbose -ErrorAction SilentlyContinue
        }
    }

	LocalConfigurationManager
    {
        ActionAfterReboot    = 'ContinueConfiguration'
        ConfigurationMode    = 'ApplyAndMonitor'
        RebootNodeIfNeeded   = $true
        AllowModuleOverWrite = $true
    }

	WindowsFeatureSet Commonroles
    {            
        Ensure = 'Present'
        Name   = $Node.WindowsFeaturesSet
    }

    Service ShellHWDetection
    {
        Name = 'ShellHWDetection'
        State = 'Stopped'
    }

    #-------------------------------------------------------------------

    foreach ($RegistryKey in $Node.RegistryKeyPresent)
    {
			
        Registry $RegistryKey.ValueName
        {
            Key       = $RegistryKey.Key
            ValueName = $RegistryKey.ValueName
            Ensure    = 'Present'
            ValueData = $RegistryKey.ValueData
            ValueType = $RegistryKey.ValueType
            Force     = $true
        }

        $dependsonRegistryKey += @("[Registry]$($RegistryKey.ValueName)")
    }

    #-------------------------------------------------------------------

	xDisk FDrive
    {
        DiskNumber  = 2
        DriveLetter = 'F'
		AllocationUnitSize = 64KB
    }

	xDisk GDrive
    {
        DiskNumber  = 3
        DriveLetter = 'G'
        AllocationUnitSize = 64KB
    }

	xDisk HDrive
    {
        DiskNumber  = 4
        DriveLetter = 'H'
        AllocationUnitSize = 64KB
    }

	#xDisk IDrive
    #{
    #    DiskNumber  = 5
    #    DriveLetter = 'I'
    #}

    # This does not always show up in time to add users, so add it manually before installing SQLServer
    # This give it time to populate

    Environment SQLPSModulePath
    {
        Name   = 'PSModulePath'
        Ensure = 'Present'
        Path   = $true
        Value  = 'G:\Program Files (x86)\Microsoft SQL Server\120\Tools\PowerShell\Modules\'
    }

    xWaitForADDomain $DomainName
    {
        DependsOn  = '[WindowsFeatureSet]Commonroles'
        DomainName = $DomainName
        RetryCount = $RetryCount
		RetryIntervalSec = $RetryIntervalSec
        DomainUserCredential = $AdminCreds
    }

	xComputer DomainJoin
	{
		Name       = $env:COMPUTERNAME
		DependsOn  = "[xWaitForADDomain]$DomainName"
		DomainName = $DomainName
		Credential = $DomainCreds
	}
    
	# reboots after DJoin
	xPendingReboot RebootForDJoin
    {
        Name      = 'RebootForDJoin'
        DependsOn = '[xComputer]DomainJoin'
    }

    # base install above - custom role install

# ---------- SQL setup and install 

    $user = ($Node.StorageAccountSourcePath -split "\\|\.")[2]
    write-verbose -Message "User is: [$user]"
    $StorageCred = [pscredential]::new( $user , (ConvertTo-SecureString -String $StorageAccountKeySource -AsPlainText -Force))
	
	# All Source Files downloaded at once
    File SQLSource
    {
        SourcePath      = $Node.StorageAccountSourcePath
		DestinationPath = 'F:\Source'
        Type            = 'Directory'
		Credential      = $StorageCred
		Recurse         = $true
		DependsOn       = '[xPendingReboot]RebootForDJoin'
    }

    WindowsFeature "NET"
    {
        Ensure = "Present"
        Name = "NET-Framework-Core"
        Source = $Node.NETPath 
    }

    xADUser svcSQL
    {
        UserName    = $Node.SQLSvcAccount
        Password    = $DomainCreds
        DomainName  = $NetBios
        Description = 'svcSQL SQL Service Account'
        Enabled     = $true
        DomainAdministratorCredential = $DomainCreds
    }

    # https://msdn.microsoft.com/en-us/library/ms143547(v=sql.120).aspx
    # File Locations for Default and Named Instances of SQL Server
    
    xSqlServerSetup xSqlServerInstall
    {
        SourcePath          = $Node.SQLSourcePath
		Action              = 'Install'
        SetupCredential     = $DomainCreds
        InstanceName        = $Node.InstanceName
        Features            = $Node.SQLFeatures
        SQLSysAdminAccounts = $SQLSvcAccount,$Node.AdminAccount
        SQLSvcAccount       = $SQLSvcAccountCreds
		AgtSvcAccount       = $SQLSvcAccountCreds
        InstallSharedDir    = "F:\Program Files\Microsoft SQL Server"
        InstallSharedWOWDir = "F:\Program Files (x86)\Microsoft SQL Server"
        InstanceDir         = "F:\Program Files\Microsoft SQL Server"
        InstallSQLDataDir   = "F:\Program Files\Microsoft SQL Server\MSSQL12.$($Node.InstanceName)\MSSQL\Data"
        SQLUserDBDir        = "F:\Program Files\Microsoft SQL Server\MSSQL12.$($Node.InstanceName)\MSSQL\Data"
        SQLUserDBLogDir     = "F:\Program Files\Microsoft SQL Server\MSSQL12.$($Node.InstanceName)\MSSQL\Logs"
        SQLTempDBDir        = "F:\Program Files\Microsoft SQL Server\MSSQL12.$($Node.InstanceName)\MSSQL\Data"
        SQLTempDBLogDir     = "F:\Program Files\Microsoft SQL Server\MSSQL12.$($Node.InstanceName)\MSSQL\Temp"                                                                  
        SQLBackupDir        = "F:\Program Files\Microsoft SQL Server\MSSQL12.$($Node.InstanceName)\MSSQL\Backup"
        DependsOn           = '[WindowsFeature]NET','[xADUser]svcSQL'
    }

    Service MSSQLSERVER
    {
        Name = 'MSSQLSERVER'
        State = 'Running'
        StartupType = 'Automatic'
        Credential = $SQLSvcAccountCreds
        DependsOn    = '[xSqlServerSetup]xSqlServerInstall'
    }

    Service SQLSERVERAGENT
    {
        Name = 'SQLSERVERAGENT'
        State = 'Running'
        StartupType = 'Automatic'
        Credential = $SQLSvcAccountCreds
        DependsOn    = '[xSqlServerSetup]xSqlServerInstall'
    }

    Service MsDtsServer120
    {
        Name = 'MsDtsServer120'
        State = 'Running'
        StartupType = 'Automatic'
        Credential = $SQLSvcAccountCreds
        DependsOn    = '[xSqlServerSetup]xSqlServerInstall'
    }

    xSqlServerFirewall xSqlServerInstall
    {
        SourcePath   = $Node.SQLSourcePath
        InstanceName = $Node.InstanceName
        Features     = $Node.SQLFeatures
        DependsOn    = '[xSqlServerSetup]xSqlServerInstall'
    }

    
	# Note you need to open the firewall ports for both the probe and service ports
	# If you have multiple Availability groups for SQL, they need to run on different ports
	# e.g. 1433,1434,1435
	# e.g. 59999,59998,59997
	xFirewall ProbePort59999
    {
        Name = 'ProbePort'
        Action = 'Allow'
        Direction = 'Inbound'
        LocalPort = 59999
        Protocol = 'TCP'
    }

	xFirewall ProbePort59998
    {
        Name = 'ProbePort'
        Action = 'Allow'
        Direction = 'Inbound'
        LocalPort = 59998
        Protocol = 'TCP'
    }

	xFirewall ProbePort59997
    {
        Name = 'ProbePort'
        Action = 'Allow'
        Direction = 'Inbound'
        LocalPort = 59997
        Protocol = 'TCP'
    }

	xFirewall SQLPorts
    {
        Name = 'SQLPorts'
        Action = 'Allow'
        Direction = 'Inbound'
        LocalPort = 1432,1431
        Protocol = 'TCP'
        Profile = 'Domain','Private'
    }

    xSQLServerLogin svcSQLLogin
    {
        Name            = $SQLSvcAccount
        LoginType       = 'WindowsUser'
		SQLServer       = $env:COMPUTERNAME
		SQLInstanceName = $Node.InstanceName
        DependsOn       = '[xSqlServerSetup]xSqlServerInstall'
    }

    xSQLServerRole svcSQLRole
    {
        Name            = $SQLSvcAccount
        ServerRole      = 'sysadmin'  # bulkadmin | dbcreator | diskadmin | processadmin | public | securityadmin | serveradmin | setupadmin | 'sysadmin'
		SQLServer       = $ENV:ComputerName
		SQLInstanceName = $Node.InstanceName
        DependsOn      = '[xSqlServerSetup]xSqlServerInstall'
        #[PsDscRunAsCredential = [PSCredential]]
    }

    xSQLServerLogin AddNTServiceClusSvc
    {
        Ensure          = 'Present'
        Name            = 'NT SERVICE\ClusSvc'
        LoginType       = 'WindowsUser'
        SQLServer       = $env:COMPUTERNAME
        SQLInstanceName = $Node.InstanceName
        PsDscRunAsCredential = $SQLSvcAccountCreds
        DependsOn       = '[xSQLServerRole]svcSQLRole'
    }

    # Add the required permissions to the cluster service login
    xSQLServerPermission AddNTServiceClusSvcPermissions
    {
        DependsOn       = '[xSQLServerLogin]AddNTServiceClusSvc'
        Ensure          = 'Present'
        NodeName        = $env:COMPUTERNAME
        InstanceName    = $Node.InstanceName
        Principal       = 'NT SERVICE\ClusSvc'
        Permission      = 'AlterAnyAvailabilityGroup','ViewServerState'
        PsDscRunAsCredential = $SQLSvcAccountCreds
    }

}

Node $AllNodes.Where{$_.Role -eq "PrimaryClusterNode"}.NodeName
{
    Write-Warning -Message "PrimaryClusterNode"
    Write-Verbose -Message "Node is: [$($ENV:ComputerName)]" -Verbose
    Write-Verbose -Message "NetBios is: [$NetBios]" -Verbose
    Write-Verbose -Message "DomainName is: [$DomainName]" -Verbose
    $SQLSvcAccount = $NetBios + '\' + $Node.SQLSvcAccount
    Write-warning "user is: $SQLSvcAccount"
    [PSCredential]$SQLSvcAccountCreds = [PSCredential]::New( $SQLSvcAccount , $AdminCreds.Password)
    write-warning -Message $SQLSvcAccountCreds.UserName
    #write-warning -Message $SQLSvcAccountCreds.GetNetworkCredential().password

		xCluster SQLCluster
		{
			Name            = $Node.ClusterName
			StaticIPAddress = $Node.ClusterIPAddress
			DomainAdministratorCredential = $DomainCreds
			DependsOn = '[WindowsFeatureSet]Commonroles'
		}

      #  xClusterQuorum FailoverClusterQuorum
      #  {
      #      Type             = 'NodeAndFileShareMajority'
      #      Resource         = $Node.FileShareWitnessPath
      #      IsSingleInstance = 'Yes'
      #      DependsOn        ='[xCluster]SQLCluster'
      #      PsDscRunAsCredential = $DomainCreds
      #  }

		xSQLServerAlwaysOnService SQLCluster
		{
			Ensure          = "Present"
			SQLServer       = $ENV:ComputerName
			SQLInstanceName = $Node.InstanceName
			RestartTimeout  = 360
			DependsOn       = '[xCluster]SQLCluster'
		} 
       
       xSQLServerEndpoint SQLCluster
       {
            Ensure          = "Present"
            Port            = 5022
            AuthorizedUser  = $SQLSvcAccount
            EndPointName    = "Hadr_endpoint"
            SQLServer       = $ENV:ComputerName
		    SQLInstanceName = $Node.InstanceName
            DependsOn       = '[xSQLServerAlwaysOnService]SQLCluster'
       }

        xSQLServerDatabase Create_Database
        {
            Ensure          = 'Present'
            SQLServer       = $ENV:ComputerName
		    SQLInstanceName = $Node.InstanceName
            Name            = $NetBios
            DependsOn       = '[xSQLServerAlwaysOnService]SQLCluster'
        }

        xSQLServerAlwaysOnAvailabilityGroup ('AOAG' + $NetBios)
        {
            Ensure          = 'Present'
            Name            = ('AOAG' + $NetBios)
            SQLInstanceName = $Node.InstanceName
            SQLServer       = $ENV:ComputerName
            DependsOn       = '[xSQLServerEndpoint]SQLCluster','[xSQLServerPermission]AddNTServiceClusSvcPermissions'
            PsDscRunAsCredential = $SQLSvcAccountCreds

        }

       xSQLServerAvailabilityGroupListener ($NetBios + '_LN')
       {
           AvailabilityGroup = ('AOAG' + $NetBios)
           InstanceName      = $Node.InstanceName
           Name              = ($NetBios + '_LN')
           NodeName          = $ENV:ComputerName
           DHCP              = $false
           Ensure            = 'Present'
           IpAddress         = $Node.AvailabilityGroupListenerIP
           Port              = 1433
           DependsOn         = "[xSQLServerAlwaysOnAvailabilityGroup]$('AOAG' + $NetBios)"
       }
       



}#Node-PrimaryClusterNode

Node $AllNodes.Where{$_.Role -eq "ReplicaServerNode"}.NodeName
{
        Write-Warning -Message "ReplicaServerNode"
        Write-Verbose -Message "Node is: [$($ENV:ComputerName)]" -Verbose
        Write-Verbose -Message "NetBios is: [$NetBios]" -Verbose
        Write-Verbose -Message "DomainName is: [$DomainName]" -Verbose
        $SQLSvcAccount = $NetBios + '\' + $Node.SQLSvcAccount
        Write-warning "user is: $SQLSvcAccount"
        [PSCredential]$SQLSvcAccountCreds = [PSCredential]::New( $SQLSvcAccount , $AdminCreds.Password)
        write-warning -Message $SQLSvcAccountCreds.UserName
        #write-warning -Message $SQLSvcAccountCreds.GetNetworkCredential().password

	  #  xWaitForCluster TECluster
	  #  {
	  #  	Name                 = $Node.ClusterName
	  #  	DependsOn            = '[WindowsFeatureSet]Commonroles'
	  #  	RetryIntervalSec     = 30
	  #  	RetryCount           = 20
	  #  }
	    
       # Join the cluster from the SQL1
	   # xCluster SQLCluster
	   # {
	   # 	Name            = $Node.ClusterName
	   # 	StaticIPAddress = $Node.ClusterIPAddress
	   # 	DomainAdministratorCredential = $DomainCreds
	   # 	DependsOn                     = '[WindowsFeatureSet]Commonroles'
       #     PsDscRunAsCredential          = $DomainCreds  
	   # }

	 #   xSQLServerAlwaysOnService SQLCluster
	 #   {
	 #   	Ensure          = "Present"
	 #   	SQLServer       = $ENV:ComputerName
	 #   	SQLInstanceName = $Node.InstanceName
	 #   	RestartTimeout  = 360
	 #   	DependsOn       = '[xWaitForCluster]TECluster'
	 #   } 
     #      
	 #   xSQLServerEndpoint SQLCluster
	 #   {
     #       Ensure         = "Present"
     #       Port           = 5022
     #       AuthorizedUser = $SQLSvcAccount
     #       EndPointName   = "Hadr_endpoint"
     #       DependsOn      = '[xWaitForCluster]TECluster'
     #       SQLServer       = $ENV:ComputerName
	 #   	SQLInstanceName = $Node.InstanceName
	 #   }

        

	 # Do the availability groups as part of manual steps.

     #   xWaitForAvailabilityGroup AOGroup1
     #   {
     #       Name             = "AOGroup1"
     #       RetryIntervalSec = 30
     #       RetryCount       = 20
     #       DependsOn        = '[xSQLServerAlwaysOnService]SQLCluster','[xCluster]SQLCluster'
     #   }
     #   
     #   xSQLAOGroupJoin AOGroup1
     #   {
     #       Ensure                = 'Present'
     #       AvailabilityGroupName = "AOGroup1"
     #       DependsOn             = '[xWaitForAvailabilityGroup]AOGroup1'
	 #   	SQLServer             = $ENV:ComputerName
	 #   	SQLInstanceName       = $Node.InstanceName
     #       #PsDscRunAsCredential  = $SQLSvcAccountCreds
     #       SetupCredential       = $SQLSvcAccountCreds
     #   }
     #
     #   xSQLServerAvailabilityGroupListener Group1listener
     #   {
     #       AvailabilityGroup = 'AOGroup1'
     #       InstanceName      = $Node.InstanceName
     #       Name              = 'Group1Listener'
     #       NodeName          = $ENV:ComputerName
     #       DHCP              = $false
     #       Ensure            = 'Present'
     #       IpAddress         = 10.0.1.100
     #       Port              = 59999
     #       DependsOn         = '[xSQLAOGroupJoin]AOGroup1'
     #   }

}#Node-ReplicaServerNode

}#Main

break

# used for troubleshooting
# F5 loads the script

#$Cred = get-credential LocalAdmin
# FNF 
$SAK = 'SmABTRmWeJ12VkpKCEBqTz8YbLcOiClh+ZZitgGPjYMN5JQjxtBhs+jgGUN/YXljTNnC/tS/Anhi9Ea6Mu/N1g=='

# BRW
$SAK = 'kBvS3pFQ7KozYtSnezXsTukLTSUkGLxf+PfjLVhXLecTC151FhtHhIrIomCUiY24JWeE9zQWNc1mSSZEjjrPVA=='
# main -ConfigurationData .\ConfigurationDataSQLx.psd1 -AdminCreds $cred -Verbose -StorageAccountKeySource $sak 
main -ConfigurationData .\ConfigurationDataSQL1.psd1 -AdminCreds $cred -Verbose -StorageAccountKeySource $sak 

Set-DscLocalConfigurationManager -Path .\Main -Force -Verbose
Start-DscConfiguration -Path .\Main -Wait -Verbose -Force

break
$Cred = get-credential brw

Get-DscLocalConfigurationManager

Start-DscConfiguration -UseExisting -Wait -Verbose -Force

Get-DscConfigurationStatus -All

$result = Test-DscConfiguration -Detailed
$result.resourcesnotindesiredstate
$result.resourcesindesiredstate


# Cannot join the other nodes until this Folder issue is fixed.

###Requires -module NTFSSecurity
# SQL1,SQL2,SQL3,SQL4,SQL5
icm -cn SQL2 -ScriptBlock {
    Get-Item -path 'C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys' | foreach {
    
        $_ | Set-NTFSOwner -Account BUILTIN\Administrators
        $_ | Clear-NTFSAccess -DisableInheritance
        $_ | Add-NTFSAccess -Account 'EVERYONE' -AccessRights ReadAndExecute -InheritanceFlags None -PropagationFlags NoPropagateInherit
        $_ | Add-NTFSAccess -Account BUILTIN\Administrators -AccessRights FullControl -InheritanceFlags None -PropagationFlags NoPropagateInherit
        $_ | Add-NTFSAccess -Account 'NT AUTHORITY\SYSTEM' -AccessRights FullControl -InheritanceFlags None -PropagationFlags NoPropagateInherit
        $_ | Get-NTFSAccess
    }
}
break
# SQL1,SQL2,SQL3,SQL4,SQL5
icm -cn SQL2 -ScriptBlock {

    dir -path 'C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys'  | foreach {
        Write-Verbose $_.fullname -Verbose
        $_ | Clear-NTFSAccess -DisableInheritance 
        $_ | Set-NTFSOwner -Account BUILTIN\Administrators
        $_ | Add-NTFSAccess -Account 'EVERYONE' -AccessRights ReadAndExecute -InheritanceFlags None -PropagationFlags NoPropagateInherit
        $_ | Add-NTFSAccess -Account BUILTIN\Administrators -AccessRights FullControl -InheritanceFlags None -PropagationFlags NoPropagateInherit
        $_ | Add-NTFSAccess -Account 'NT AUTHORITY\SYSTEM' -AccessRights FullControl -InheritanceFlags None -PropagationFlags NoPropagateInherit
        
        $_ | Get-NTFSAccess
   
    }
}



break
icm -cn SQL1,SQL2,SQL3,SQL4,SQL5 -ScriptBlock {
 #install-module -name NTFSSecurity -force -Verbose
 get-module -name NTFSSecurity -ListAvailable
 }

 # Confirm that the Cluster Probeport is set on the Service

 $ClusterNetworkName = "Cluster Network 1" # the cluster network name (Use Get-ClusterNetwork on Windows Server 2012 of higher to find the name)
$IPResourceName = "TestAG_10.0.1.100" # the IP Address resource name
$ILBIP = "10.0.1.100" # the IP Address of the Internal Load Balancer (ILB). This is the static IP address for the load balancer you configured in the Azure portal.
[int]$ProbePort = 59999

Import-Module FailoverClusters

Get-ClusterResource $IPResourceName | Set-ClusterParameter -Multiple @{"Address"="$ILBIP";"ProbePort"=$ProbePort;"SubnetMask"="255.255.255.0";"Network"="$ClusterNetworkName";"EnableDhcp"=0}

