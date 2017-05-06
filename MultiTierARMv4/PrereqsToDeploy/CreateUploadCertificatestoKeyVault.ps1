#
# CreateUploadCertificatestoKeyVault.ps1
#
# Note this Wildcard certificate can be used on all Web Server in the Environment.
# The deployment automatically installs this Cert in all required stores for it to be trusted.
# The cert/s can also be used for the WAF (Web Application Firewall) SSL and Authenication certs.

$CertPath = 'D:\Azure\Certs'
#--------------------------------------------------------
# Create Web cert *.contoso.com
$cert = New-SelfSignedCertificate -NotAfter (Get-Date).AddYears(5) -DnsName *.contoso.com,*.AlpineSkiHouse.com,*.Fabrikam.com,*.TreyResearch.net -CertStoreLocation Cert:\LocalMachine\My
$cert
$PW = read-host -AsSecureString
Export-PfxCertificate -Password $PW -FilePath $CertPath\MultiDomainwildcard.pfx -Cert $cert
Export-Certificate -FilePath $CertPath\MultiDomainwildcard.cer -Cert $cert 

#--------------------------------------------------------
# Upload the cert to Azure Keyvault/s
$rgName = 'rgContosoGlobal'
$kVaultName = 'kvContosoEastUS2'
$kVaultName = 'kvContosoEastUS'

# Run this twice or for each region that you want to deploy into
Import-AzureKeyVaultCertificate -FilePath $CertPath\MultiDomainwildcard.pfx -Name MultiDomainwildcard -VaultName $kVaultName -Password $PW


$MultiDomainwildcard = Get-AzureKeyVaultSecret -VaultName $kVaultName -Name MultiDomainwildcard
$MultiDomainwildcard.Id
# OR
Get-AzureKeyVaultCertificate -VaultName $kVaultName -Name MultiDomainwildcard

# e.g. https://kvcontosoeastus2.vault.azure.net:443/secrets/MultiDomainwildcard/07534e07585c4f6ba3ffd1769af55d01

# We also need the base64 password uploaded for the Web Application Firewall, that will also use this cert
# also do this for all regions

# Front End SSL Cert
$fileContentBytes = Get-Content -Path $CertPath\MultiDomainwildcard.pfx -Encoding Byte
$SS = [System.Convert]::ToBase64String($fileContentBytes) | ConvertTo-SecureString -AsPlainText -Force
Set-AzureKeyVaultSecret -VaultName $kVaultName -Name MultiDomainwildcardBase64 -SecretValue $SS -ContentType txt

# Authentication certs
$fileContentBytes = Get-Content -Path $CertPath\MultiDomainwildcard.cer -Encoding Byte
$SS = [System.Convert]::ToBase64String($fileContentBytes) | ConvertTo-SecureString -AsPlainText -Force
Set-AzureKeyVaultSecret -VaultName $kVaultName -Name MultiDomainwildcardBase64Public -SecretValue $SS -ContentType txt

#--------------------------------------------------------
# Ensure the KeyVault is enabled for template deployment

Set-AzureRmKeyVaultAccessPolicy -VaultName $kVaultName -ResourceGroupName $rgName -EnabledForDeployment -EnabledForTemplateDeployment -EnabledForDiskEncryption
Get-AzureRMKeyVault -VaultName $kVaultName

# Ensure you allow the particular user access to the keys, which allows access to certs and creds
#Set-AzureKeyVaultAccessPolicy -VaultName kvContoso -ServicePrincipalName '8b58c31d-7cab-4152-979b-096f8f88621e' -PermissionsToKeys all