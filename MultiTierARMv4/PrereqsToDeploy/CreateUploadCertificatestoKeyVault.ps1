#
# CreateUploadCertificatestoKeyVault.ps1
#
# Note this Wildcard certificate can be used on all Web Server in the Environment.
# The deployment automatically installs this Cert in all required stores for it to be trusted.
$kVaultName = 'kvContoso'
$rgName = 'rgContosoGlobal'
$CertPath = 'D:\Azure'
#--------------------------------------------------------
# Create Web cert *.contoso.com
$cert = New-SelfSignedCertificate -DnsName *.contoso.com -CertStoreLocation Cert:\LocalMachine\My
$cert
$PW = read-host -AsSecureString
Export-PfxCertificate -Password $PW -FilePath $CertPath\contosowildcard.pfx -Cert $cert
Export-Certificate -FilePath $CertPath\contosowildcard.cer -Cert $cert 

#--------------------------------------------------------
# Upload certs to KeyVault

$FileName = "$CertPath\contosowildcard.pfx"

$certPassword = Read-Host -Prompt EnterPlainTextPassword

$fileContentBytes = get-content $fileName -Encoding Byte
$fileContentEncoded = [System.Convert]::ToBase64String($fileContentBytes)

$jsonObject = @"
 {
 "data"     : "$filecontentencoded",
 "dataType" : "pfx",
 "password" : "$certPassword"
 }
"@

$jsonObjectBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonObject)
$jsonEncoded     = [System.Convert]::ToBase64String($jsonObjectBytes)

$secret = ConvertTo-SecureString -String $jsonEncoded -AsPlainText -Force
Set-AzureKeyVaultSecret -VaultName $kVaultName -Name contosowildcard -SecretValue $secret

$contosowildcard = Get-AzureKeyVaultSecret -VaultName $kVaultName -Name contosowildcard
$contosowildcard.Id
# e.g. https://kvcontoso.vault.azure.net:443/secrets/contosowildcard

#--------------------------------------------------------

Set-AzureRmKeyVaultAccessPolicy -VaultName $kVaultName -ResourceGroupName $rgName -EnabledForDeployment -EnabledForTemplateDeployment -EnabledForDiskEncryption
Get-AzureRMKeyVault -VaultName $kVaultName

#Set-AzureKeyVaultAccessPolicy -VaultName kvContoso -ServicePrincipalName '8b58c31d-7cab-4152-979b-096f8f88621e' -PermissionsToKeys all