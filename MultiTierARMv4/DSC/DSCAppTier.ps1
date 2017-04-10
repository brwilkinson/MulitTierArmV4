#$Cred = get-credential LocalAdmin

Configuration Main
{
Param ( 
		[String]$DomainName = 'contoso.com',
		[PSCredential]$AdminCreds,
		[Int]$RetryCount = 20,
		[Int]$RetryIntervalSec = 120,
        $ThumbPrint = '606295CAE217319DC730F8F16D52C6BEF636047B',
        $StorageAccountKeySource
		)


Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -ModuleName xComputerManagement
Import-DscResource -ModuleName xActiveDirectory
Import-DscResource -ModuleName xStorage
Import-DscResource -ModuleName xPendingReboot
Import-DscResource -ModuleName xWebAdministration
Import-DscResource -ModuleName xPSDesiredStateConfiguration 
Import-DscResource -ModuleName SecurityPolicyDSC 


[PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$DomainName\$(($AdminCreds.UserName -split '\\')[-1])", $AdminCreds.Password)

#Node $AllNodes.NodeName
node $AllNodes.NodeName
{
    if($NodeName -eq "localhost") {
        [string]$computername = $env:COMPUTERNAME
    }
    else {
        Write-Verbose $Nodename.GetType().Fullname
        [string]$computername = $Nodename
    } 
    Write-Verbose -Message $computername -Verbose

	LocalConfigurationManager
    {
        ActionAfterReboot   = 'ContinueConfiguration'
        ConfigurationMode   = 'ApplyAndMonitor'
        RebootNodeIfNeeded  = $true
        AllowModuleOverWrite = $true
    }


      #-------------------------------------------------------------------
      
	  foreach ($Feature in $Node.WindowsFeaturePresent)
      {
         WindowsFeature $Feature {
            Name   = $Feature
            Ensure = 'Present'
			IncludeAllSubFeature = $true
			#Source = $ConfigurationData.NonNodeData.WindowsFeatureSource
         }
         $dependsonFeatures += @("[WindowsFeature]$Feature")
      }

    #-------------------------------------------------------------------
    if ($Node.WindowsFeatureSetPresent)
    {
        WindowsFeatureSet WindowsFeatureSetPresent
        {
            Ensure = 'Present'
            Name   = $Node.WindowsFeatureSetPresent
        }
    }

	#-------------------------------------------------------------------
    if ($Node.ServiceSetStopped)
    {
        ServiceSet ServiceSetStopped
        {
            Name  = $Node.ServiceSetStopped
            State = 'Stopped'
        }
    }
	#-------------------------------------------------------------------
    foreach ($disk in $Node.DisksPresent)
      {
         xDisk $disk.DriveLetter {
            DiskNumber  = $disk.DiskNumber
			DriveLetter = $disk.DriveLetter
         }
         $dependsonDisksPresent += @("[xDisk]$($disk.DriveLetter)")
      }
    #-------------------------------------------------------------------

    # Dont need SXS, NET-Framework-Core is part of the Image
    #File InstallFiles
    #{
    #   SourcePath      = $Node.StorageAccountInstallfilesSourcePath
	#	DestinationPath = $node.installdir
    #   Type            = 'Directory'
	#	Credential      = $StorageCred
	#	Recurse         = $true
    #}

    # Dont need this, is part of the Image
    #WindowsFeature NetCore
    #{
    #    Ensure = 'Present'
    #    Name   = 'NET-Framework-Core'
    #    Source = "$($node.installdir)/sxs"
    #}

    xWaitForADDomain $DomainName
    {
        DependsOn  = $dependsonFeatures
        DomainName = $DomainName
        RetryCount = $RetryCount
		RetryIntervalSec = $RetryIntervalSec
        DomainUserCredential = $AdminCreds
    }

	xComputer DomainJoin
	{
		Name       = $computername
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

    foreach ($UserRightsAssignment in $Node.UserRightsAssignmentPresent)
    {
      
        UserRightsAssignment $UserRightsAssignment.policy
        {
            Identity     = $UserRightsAssignment.identity
            Policy       = $UserRightsAssignment.policy       
        }

        $dependsonUserRightsAssignment += @("[UserRightsAssignment]$($UserRightsAssignment.policy)")
    }
    
	#-------------------------------------------------------------------
    if ($Node.ServiceSetStarted)
    {
        ServiceSet ServiceSetStarted
        {
            Name        = $Node.ServiceSetStarted
            State       = 'Running'
		    StartupType = 'Automatic'
		    DependsOn   = @('[WindowsFeatureSet]WindowsFeatureSetPresent') + $dependsonRegistryKey
        }
    }

	#-------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------------------------------------

    #To clean up resource names use a regular expression to remove spaces, slashes an colons
    $StringFilter = "\\|\s|:",''
    
    $user = $Node.StorageAccountName
    write-verbose -Message "User is: [$user]"
    $StorageCred = [pscredential]::new( $user , (ConvertTo-SecureString -String $StorageAccountKeySource -AsPlainText -Force))
    
    #Set environment path variables

    
    #-------------------------------------------------------------------

      foreach ($EnvironmentPath in $Node.EnvironmentPathPresent)
      {
        $Name = $EnvironmentPath -replace $StringFilter
        Environment $Name
        {
            Name    = "Path"
            Value   = $EnvironmentPath
            Path    = $true
        }
        $dependsonEnvironmentPath += @("[Environment]$Name")
      }



     #-------------------------------------------------------------------

      foreach ($Dir in $Node.DirectoryPresent)
      {
        $Name = $Dir -replace $StringFilter
        File $Name
        {
            DestinationPath = $Dir
            Type            = 'Directory'
        }
        $dependsonDir += @("[File]$Name")
      }

     #-------------------------------------------------------------------     
      foreach ($File in $Node.DirectoryPresentSource)
      {
        $Name = $File.filesSourcePath -replace $StringFilter
        File $Name
        {
            SourcePath      = $File.filesSourcePath
            DestinationPath = $File.filesDestinationPath
            Ensure          = 'Present'
            Recurse         = $true
            Credential      = $StorageCred  
        }
        $dependsonDirectory += @("[File]$Name")
      }

      #-----------------------------------------
      foreach ($WebSite in $Node.WebSiteAbsent)
      {
         $Name =  $WebSite.Name -replace ' ',''
         xWebsite $Name 
         {
            Name         = $WebSite.Name
            Ensure       = 'Absent'
            State        = 'Stopped'
            PhysicalPath = 'C:\inetpub\wwwroot'
            DependsOn    = $dependsonFeatures
         }
         $dependsonWebSitesAbsent += @("[xWebsite]$Name")
      }

     #-------------------------------------------------------------------
       foreach ($AppPool in $Node.WebAppPoolPresent)
      { 
		  $Name = $AppPool.Name -replace $StringFilter

		 xWebAppPool $Name 
		{
			Name                  = $AppPool.Name
			State                 = 'Started'
			autoStart             = $true
			DependsOn             = '[ServiceSet]ServiceSetStarted'
			managedRuntimeVersion = $AppPool.Version
            identityType          = 'SpecificUser'
            Credential            = $DomainCreds
            enable32BitAppOnWin64 = $AppPool.enable32BitAppOnWin64
		}
        $dependsonWebAppPool += @("[xWebAppPool]$Name")
      }
     #-------------------------------------------------------------------


      foreach ($WebSite in $Node.WebSitePresent)
      {
         $Name = $WebSite.Name -replace $StringFilter
		  
		  xWebsite $Name 
         {
            Name            = $WebSite.Name
            ApplicationPool = $WebSite.ApplicationPool
            PhysicalPath    = $Website.PhysicalPath
            State           = 'Started'
            DependsOn       = $dependsonWebAppPools
            BindingInfo = foreach ($Binding in $WebSite.BindingPresent)
                {
                    MSFT_xWebBindingInformation  
                        {  
                            Protocol  = $binding.Protocol
                            Port      = $binding.Port
                            IPAddress = $binding.IpAddress
                            HostName  = $binding.HostHeader
                            CertificateThumbprint = $ThumbPrint
                            CertificateStoreName = "MY"   
                        }
                }
         }
         $dependsonWebSites += @("[xWebsite]$Name")
      }

      #------------------------------------------------------
      foreach ($WebVirtualDirectory in $Node.VirtualDirectoryPresent)
      {
        xWebVirtualDirectory $WebVirtualDirectory.Name
        {
            Name                 = $WebVirtualDirectory.Name
            PhysicalPath         = $WebVirtualDirectory.PhysicalPath
            WebApplication       = $WebVirtualDirectory.WebApplication
            Website              = $WebVirtualDirectory.Website
            PsDscRunAsCredential = $DomainCreds
            Ensure               = 'Present'
            DependsOn            = $dependsonWebSites
        }
         $dependsonWebVirtualDirectory += @("[xWebVirtualDirectory]$($WebVirtualDirectory.name)")
      }

      # set virtual directory creds
      foreach ($WebVirtualDirectory in $Node.VirtualDirectoryPresent)
      {
          $vdname	= $WebVirtualDirectory.Name
          $wsname	= $WebVirtualDirectory.Website
          $pw		= $DomainCreds.GetNetworkCredential().Password
		  $Domain	= $DomainCreds.GetNetworkCredential().Domain
		  $UserName = $DomainCreds.GetNetworkCredential().UserName

          script $vdname  {
                DependsOn = $dependsonWebVirtualDirectory 
                
                GetScript = {
                    Import-Module -Name "webadministration"
                    $vd = Get-WebVirtualDirectory -site  $using:wsname -Name $vdname
                    @{
                        path           = $vd.path
                        physicalPath   = $vd.physicalPath
                        userName       = $vd.userName
                     }
                }#Get
                SetScript = {
                    Import-Module -Name "webadministration"
                    Set-ItemProperty -Path "IIS:\Sites\$using:wsname\$using:vdname" -Name userName -Value "$using:domain\$using:UserName"
                    Set-ItemProperty -Path "IIS:\Sites\$using:wsname\$using:vdname" -Name password -Value $using:pw
                }#Set 
                TestScript = {
                    Import-Module -Name "webadministration"
                    Write-warning $using:vdname
                    $vd = Get-WebVirtualDirectory -site  $using:wsname -Name $using:vdname
                    if ($vd.userName -eq  "$using:domain\$using:UserName") {
                        $true
                    }
                    else {
                        $false
                    }

                }#Test
            }#[Script]VirtualDirCreds
      }
            
      #------------------------------------------------------
      foreach ($WebApplication in $Node.WebApplicationsPresent)
      {
         xWebApplication $WebApplication.Name
         {
            Name         = $WebApplication.Name
            PhysicalPath = $WebApplication.PhysicalPath
            WebAppPool   = $WebApplication.ApplicationPool
            Website      = $WebApplication.Site
            Ensure       = 'Present'
            DependsOn    = $dependsonWebSites
         }
         $dependsonWebApplication += @("[xWebApplication]$($WebApplication.name)")
      }

      #-------------------------------------------------------------------
	  # install any packages without dependencies
      foreach ($Package in $Node.SoftwarePackagePresent)
      {
		$Name = $Package.Name -replace $StringFilter
		xPackage $Name
		{
			Name            = $Package.Name
			Path            = $Package.Path
			Ensure          = 'Present'
			ProductId       = $Package.ProductId
			RunAsCredential = $DomainCreds
            DependsOn       = $dependsonWebSites
            Arguments       = $Package.Arguments
		}

		$dependsonPackage += @("[xPackage]$($Name)")
	  }

	  #-------------------------------------------------------------------
	  # install new services
      foreach ($NewService in $Node.NewServicePresent)
      {
		$Name = $NewService.Name -replace $StringFilter
		xService $Name
		{
			Name            = $NewService.Name
			Path            = $NewService.Path
			Ensure          = 'Present'
			Credential      = $DomainCreds
			Description     = $NewService.Description 
            StartupType     = $NewService.StartupType
            State           = $NewService.State
            DependsOn       = $apps 
		}
        
		$dependsonService += @("[xService]$($Name)")
	  }

      #------------------------------------------------------

}
}#Main


break




$SAK = read-host enterstorageaccountkey
    
#$sakss = ConvertTo-SecureString -String $SAK -AsPlainText -Force
Get-ChildItem -Path .\Main -Filter *.mof | Remove-Item 

main -ConfigurationData .\JMP-ConfigurationData.psd1 -AdminCreds $cred -Verbose -StorageAccountKeySource $sak
#main -ConfigurationData .\WebFE-ConfigurationData.psd1 -AdminCreds $cred -Verbose -StorageAccountKeySource $sak

Set-DscLocalConfigurationManager -Path .\Main -Force 
Start-DscConfiguration -Path .\Main -Wait -Verbose -Force

# used for troubleshooting
# F5 loads the script

break
$a = Read-Host -AsSecureString
$cred = [pscredential]::new('brw',$a)

#$Cred = get-credential LocalAdmin
icm -cn $computername -Credential $cred -ScriptBlock {hostname}

main -ConfigurationData .\*-ConfigurationData.psd1 -AdminCreds $cred -Verbose -StorageAccountKeySource $sak 
Start-DscConfiguration -Path .\Main -Wait -Verbose -Force

Get-DscLocalConfigurationManager

Start-DscConfiguration -UseExisting -Wait -Verbose -Force

Get-DscConfigurationStatus -All

Test-DscConfiguration

$r = Test-DscConfiguration -detailed
$r.ResourcesNotInDesiredState
$r.ResourcesInDesiredState

# Install-Module -name xComputerManagement,xActiveDirectory,xStorage,xPendingReboot,xWebAdministration,xPSDesiredStateConfiguration,SecurityPolicyDSC  -Force

Remove-Module

Uninstall-Module 
Install-Module -name xComputerManagement,xActiveDirectory,xStorage,xPendingReboot,xWebAdministration,xPSDesiredStateConfiguration,SecurityPolicyDSC  -Force

icm WebFE01 {
   Get-Module -ListAvailable -Name  xComputerManagement,xActiveDirectory,xStorage,xPendingReboot,xWebAdministration,xPSDesiredStateConfiguration,SecurityPolicyDSC | foreach {
        $_.ModuleBase | Remove-Item -Recurse -Force
   }
   Find-Package -ForceBootstrap -Name xComputerManagement
   Install-Module -name xComputerManagement,xActiveDirectory,xStorage,xPendingReboot,xWebAdministration,xPSDesiredStateConfiguration,SecurityPolicyDSC  -Force -Verbose
}
