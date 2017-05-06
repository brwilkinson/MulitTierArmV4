#
# ConfigurationData.psd1
#

@{ 
AllNodes = @( 
    @{ 
        NodeName = "LocalHost" 
        PSDscAllowPlainTextPassword = $true
		PSDscAllowDomainUser = $true

		DisksPresent             = @{DriveLetter="F"; DiskNumber=2}
		StorageAccountName      = 'saeastus2'
		ServiceSetStopped        = 'ShellHWDetection'

     } 
 )
}