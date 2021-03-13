Param(
	[string]$websiteName = "",
	[string]$domainName = "",
	[string]$appName = "",
	[bool] $availableToOtherTenants = 0
)

$userAccessScopeApi = '{
		"lang": null,
		"origin": "Application",		
		"adminConsentDescription": "Allow the application to access --appName-- on behalf of the signed-in user.",
		"adminConsentDisplayName": "Access --appName--",
		"id": "--- replaced in scripts ---",
		"isEnabled": true,
		"type": "User",
		"userConsentDescription": "Allow the application to access --appName-- on your behalf.",
		"userConsentDisplayName": "Access --appName--",
		"value": "access_as_user"
}' 

##################################
### Validate Params
##################################
function validateParams {
	if (!$websiteName) { 
		Write-Host "Website name cannot be null." -ForegroundColor Red 
		exit 1
	}
	if ($websiteName -notmatch '!azurewebsites.net') { 
		Write-Host "Teams apps does not allow azurewebsites.net in URL, use a custom domain.')." -ForegroundColor Red 
		exit 1
	}
	if ($websiteName -notmatch 'https') { 
		Write-Host "Teams apps needs https to function')." -ForegroundColor Red 
		exit 1
	}
	if (!$domainName) { 
		Write-Host "Azure AD tenant’s domain name cannot be null." -ForegroundColor Red 
		exit 1
	}
	if ($domainName -notmatch '^[-a-zA-Z0-9]+\.onmicrosoft\.com') {
		Write-Host "Azure AD tenant’s domain name can only consist of alphabets, numbers and hyphen (-) in the format <name>.onmicrosoft.com" -ForegroundColor Red 
		exit 1
	}
}

##################################
### Get Tenant Id from domain name
##################################
function getTenantIdFromDomainName {
	Param(
		[Parameter(Mandatory = $true)][string]$domainName
	)
	try {
		$account = az account show | ConvertFrom-Json
		$graphAccessToken = az account get-access-token --resource "https://graph.windows.net" | ConvertFrom-Json

		$getTenantDetailUrl = "https://graph.windows.net/" + $domainName + "/tenantDetails?api-version=1.6"

		$headers = New-Object 'System.Collections.Generic.Dictionary[String,String]'
		$headers.Add("Content-Type", "application/json")
		$headers.Add("Authorization", "Bearer " + $graphAccessToken.accessToken)

		$getTenantDetailResponse = Invoke-RestMethod -Uri $getTenantDetailUrl -Method GET -Headers $headers
		$tenantId = $getTenantDetailResponse.value[0].objectId
		return $tenantId
	}
	catch {
		Write-Host "We could not fetch your Azure AD tenant’s details. Please ensure that the domain name '$domainName' is correct and exists in '$($account.name)' subscription." -ForegroundColor Red 
		exit 1
	}
}

if ([string]::IsNullOrEmpty($websiteName)) {
	$websiteName = $(Write-Host "Enter you teams app website name: (example: https://teamseid.municipality.se)" -ForegroundColor Green -NoNewline; Read-Host).Trim()
}

if ([string]::IsNullOrEmpty($domainName)) {
	$domainName = $(Write-Host "Enter your Azure AD’s tenant domain name (example: municipality.onmicrosoft.com): " -ForegroundColor Green -NoNewline; Read-Host).Trim()
}
if ([string]::IsNullOrEmpty($appName)) {
	$domainName = $(Write-Host "Enter your Azure AD application name (example: teamseid): " -ForegroundColor Green -NoNewline; Read-Host).Trim()
}

validateParams
$tenantId = getTenantIdFromDomainName($domainName)

Write-Host "The script can take a few minutes to complete. Please wait... " -ForegroundColor Green

#Initialize variables
$appReplyURLs = @( $websiteName + "/login",
	
$identifierApi = New-Guid

##################################
### Create/Update Azure App
##################################

#Check if app exists with the same name or not
$existingApp = az ad app list --filter "displayname eq '$appName'" | ConvertFrom-Json
if ($existingApp) {
	$response = $(Write-Host "The app with the name, '$appName' already exists. This action will delete the existing app and create a new app, do you want to continue? (Y/N): " -ForegroundColor Yellow -NoNewline; Read-Host)
	if ( $response -eq "Y" || $response -eq "y") {
		# If app with the same name exists delete it before proceeding
		az ad app delete --id $existingApp.appId
	}   
	else { exit 1 }
}

$aadApp = az ad app create `
	--display-name $appName `
	--available-to-other-tenants $availableToOtherTenants `
	--oauth2-allow-implicit-flow  false `
	--reply-urls $appReplyURLs 

$aadAppResult = $aadApp | ConvertFrom-Json
$appId = $aadAppResult.appId
$domainOnlyURL = ([System.Uri]$websiteName).Host -replace '^www\.'
$identifierUrlApi = "api://$domainOnlyURL/$appId/access_as_user"

##################################
###  Add scopes (oauth2Permissions)
##################################

# 1. Read oauth2Permissions
$oauth2PermissionsApi = $aadAppResult.oauth2Permissions
if ($oauth2PermissionsApi) {
	# 2. Set isEnabled to false from the defualt scope, because we want to remove this
	$oauth2PermissionsApi[0].isEnabled = 'false'
	$oauth2PermissionsApi = ConvertTo-Json -InputObject @($oauth2PermissionsApi) 
	# Disable oauth2Permission in Azure App Registration
	$oauth2PermissionsApi | Out-File -FilePath .\oauth2Permissionsold.json
	az ad app update --id $appId --set oauth2Permissions=`@oauth2Permissionsold.json
	# 3. Delete the default oauth2Permission
	az ad app update --id $appId --set oauth2Permissions='[]'
}
# 4. Add the new scope required add the new oauth2Permissions values
$oauth2PermissionsApiNew = (ConvertFrom-Json -InputObject $userAccessScopeApi)
$oauth2PermissionsApiNew[0].id = $identifierApi
$oauth2PermissionsApiNew[0].adminConsentDescription = $oauth2PermissionsApiNew[0].adminConsentDescription.Replace('--appName--', $websiteName);
$oauth2PermissionsApiNew[0].adminConsentDisplayName = $oauth2PermissionsApiNew[0].adminConsentDisplayName.Replace('--appName--', $websiteName);
$oauth2PermissionsApiNew[0].userConsentDescription = $oauth2PermissionsApiNew[0].userConsentDescription.Replace('--appName--', $websiteName);
$oauth2PermissionsApiNew[0].userConsentDisplayName = $oauth2PermissionsApiNew[0].userConsentDisplayName.Replace('--appName--', $websiteName);
$oauth2PermissionsApiNew = ConvertTo-Json -InputObject @($oauth2PermissionsApiNew) 
$oauth2PermissionsApiNew | Out-File -FilePath .\oauth2Permissionsnew.json
az ad app update --id $appId --identifier-uris $identifierUrlApi --set oauth2Permissions=`@oauth2Permissionsnew.json
#5. Disable Implicit Grant ID Token 
$objectId = $aadAppResult.objectId
az rest --method PATCH --uri "https://graph.microsoft.com/v1.0/applications/$objectId" --headers 'Content-Type=application/json' --body '{\"web\":{\"implicitGrantSettings\":{\"enableIdTokenIssuance\":false}}}'
#6. Remove the temporarily created files
Remove-Item -Path .\oauth2Permissionsold.json
Remove-Item -Path .\oauth2Permissionsnew.json

##################################
### Generate Secret
##################################
$PwdCreds = az ad app credential reset --id $appId --append --credential-description "Primary" --years 99 | ConvertFrom-Json

##################################
### Generate Output
##################################
$Outputs = [ordered]@{
	"Client ID"     = $PwdCreds.appId;
	"Client Secret" = $PwdCreds.password;
	"Tenant Id"     = $PwdCreds.tenant;
	"Tenant name"   = $domainName.Replace('.onmicrosoft.com', '');
	"Teams App GUID - use this when creating the Teams App" = $PwdCreds.AppId;
}

$Outputs  | ConvertTo-Json 
Write-Host "Please copy the above values from the terminal to complete the next step(s) in the Microsoft Community Training platform login configuration flow." -ForegroundColor Green
