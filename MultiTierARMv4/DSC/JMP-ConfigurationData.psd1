#
# ConfigurationData.psd1
#

@{ 
AllNodes = @( 
    @{ 
        NodeName                    = "LocalHost" 
        PSDscAllowPlainTextPassword = $true
		PSDscAllowDomainUser        = $true

		DisksPresent                = @{DriveLetter="F"; DiskNumber=2}
		StorageAccountName          = 'saeastus2'
		ServiceSetStopped           = 'ShellHWDetection'

		# IncludesAllSubfeatures
		WindowsFeaturePresent       = $Null

		# Single set of features
		WindowsFeatureSetPresent    = $Null

		DirectoryPresent            = 'F:\Source'

		DirectoryPresentSource  = @{filesSourcePath      = '\\saeastus2.file.core.windows.net\source\OMSDependencyAgent\'
									filesDestinationPath = 'F:\Source\OMSDependencyAgent\'}

		SoftwarePackagePresent    = @{ Name            = 'Microsoft Monitoring Agent'
			                          Path            = 'F:\Source\OMSDependencyAgent\InstallDependencyAgent-Windows.exe'
			                          ProductId       = '{6D765BA4-C090-4C41-99AD-9DAF927E53A5}'
                                      Arguments       = '/S'}
     } 
 )
}