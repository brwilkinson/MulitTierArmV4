Configuration Main
{
Param ( 
		[String]$DomainName = 'Contoso.com',
		[PSCredential]$AdminCreds,
		[Int]$RetryCount = 20,
		[Int]$RetryIntervalSec = 120,
        [String]$ThumbPrint = 'D619F4B333D657325C976F97B7EF5977E740E791',
		[String]$StorageAccountKeySource
		)

Import-DscResource -ModuleName PSDesiredStateConfiguration
Import-DscResource -ModuleName xComputerManagement
Import-DscResource -ModuleName xActiveDirectory
Import-DscResource -ModuleName xStorage
Import-DscResource -ModuleName xPendingReboot
Import-DscResource -ModuleName xWebAdministration
Import-DscResource -ModuleName xSQLServer

[PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$DomainName\$(($AdminCreds.UserName -split '\\')[-1])", $AdminCreds.Password)

Node $AllNodes.Where{$_.Role -eq "PrimaryClusterNode"}.NodeName
{
    Write-Verbose -Message $Node.NodeName -Verbose
    if ($Node.WindowsFeaturesSet)
    {
        $Node.WindowsFeaturesSet | foreach {
            Write-Verbose -Message $_ -Verbose -ErrorAction SilentlyContinue
        }
    }

	LocalConfigurationManager
    {
        ActionAfterReboot   = 'ContinueConfiguration'
        ConfigurationMode   = 'ApplyAndMonitor'
        RebootNodeIfNeeded  = $true
        AllowModuleOverWrite = $true
    }

	WindowsFeatureSet Commonroles
    {            
        Ensure = 'Present'
        Name   = $Node.WindowsFeaturesSet
    }

	xDisk FDrive
    {
        DiskNumber  = 2
        DriveLetter = 'F'
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
	
	File SQLSource
    {
        SourcePath      = $Node.StorageAccountSourcePath
		DestinationPath = 'F:\Source'
        Type            = 'Directory'
		Credential      = $StorageCred
		Recurse         = $true
    }

}
}#Main


break

# used for troubleshooting
# F5 loads the script

$Cred = get-credential brw
$SAK = 'kBvS3pFQ7KozYtSnezXsTukLTSUkGLxf+PfjLVhXLecTC151FhtHhIrIomCUiY24JWeE9zQWNc1mSSZEjjrPVA=='
$sakss = ConvertTo-SecureString -String $SAK -AsPlainText -Force
main -ConfigurationData .\ConfigurationDataSQL.psd1 -AdminCreds $cred -Verbose -StorageAccountKeySource $sakss 
Set-DscLocalConfigurationManager -Path .\Main -Force -Verbose
Start-DscConfiguration -Path .\Main -Wait -Verbose -Force

Get-DscLocalConfigurationManager

Start-DscConfiguration -UseExisting -Wait -Verbose -Force

Get-DscConfigurationStatus -All
