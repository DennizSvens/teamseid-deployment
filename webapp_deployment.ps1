$AppName = $(Write-Host "Web App Name (example: municipalityeid): " -ForegroundColor Green -NoNewline; Read-Host).Trim()
$ResourceGroupName = $(Write-Host "Resource Group Name (Will create a new resource group if not created): " -ForegroundColor Green -NoNewline; Read-Host).Trim()


$GitHubRepo="https://github.com/DennizSvens/teams-app-eid"
$Location="West Europe"

if(-not (Get-AzResourceGroup $ResourceGroupName -ErrorAction "SilentlyContinue")) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location
}
New-AzAppServicePlan -Name $AppName -Location $location -ResourceGroupName $ResourceGroupName -Tier Free -Linux
$WebApp = New-AzWebApp -Name $AppName -Location $location -AppServicePlan $AppName -ResourceGroupName $ResourceGroupName
$PropertiesObject = @{
    repoUrl = "$GitHubRepo";
    branch = "master";
    isManualIntegration = "true";
}
Set-AzResource -Properties $PropertiesObject -ResourceGroupName $ResourceGroupName -ResourceType Microsoft.Web/sites/sourcecontrols -ResourceName $AppName/web -ApiVersion 2018-02-01 -Force
$AppSettingsKVP = @{
'AAD_TENANT_NAME'='';
'AADAPP_CLIENT_ID'='';
'AADAPP_CLIENT_SECRET'='';
'AUTH_TESTING'='false';
'BANKID_CERT'='';
'BANKID_ENABLE'='false';
'BANKID_PASS'='';
'BASE_URL'='';
'COOKIE_SECRET'='';
'FREJA_CERT'='';
'FREJA_ENABLE'='false';
'FREJA_MINIMUM_REGISTRATION_LEVEL'='';
'FREJA_PASS'='';
'FREJAORGID_ENABLE'='';
'FUNKTIONSTJANSTER_BANKID'='false';
'FUNKTIONSTJANSTER_FREJA'='false';
'FUNKTIONSTJANSTER_POLICY'='';
'FUNKTIONSTJANSTER_RP_DISPLAYNAME'='';
'MESSAGE_SUBJECT'='';
'SECURE_MEETINGS_ENABLED'='false';
'SENDER_DOMAINS'='';
'SENDER_HOSTS'='';
'SMTP_DOMAIN'='';
'SMTP_ENABLED'='false';
'SVENSKEIDENTITET_APIKEY'='';
'SVENSKEIDENTITET_BANKID'='false';
'SVENSKEIDENTITET_BANKIDKEY'='';
'SVENSKEIDENTITET_FREJA'='false';
'SVENSKEIDENTITET_FREJAEIDKEY'='';
'TEAMS_INTEGRATED'='';
'TEAMS_TEAM_TABNAME'='Legitimera';
'USE_SSL'='false';}


$EidProvider = $(Write-Host "Which eID provider do you want to use? `n1. CGI Funktionstjänster`n2. Svensk E-Identitet`n3. Standalone (BankID or Freja without 3rd party)" -ForegroundColor Green; Read-Host).Trim()
$BankID = $(Write-Host "Enable BankID? (true/false): " -ForegroundColor Green; Read-Host).Trim()
$FrejaEID = $(Write-Host "Enable FrejaEID? (true/false): " -ForegroundColor Green; Read-Host).Trim()
switch($EidProvider) {
    "1" {
        $AppSettingsKVP.FUNKTIONSTJANSTER_POLICY = $(Write-Host "Enter API key for funktionstjänster (logtest020 for test)" -ForegroundColor Green -NoNewline; Read-Host).Trim()
        $AppSettingsKVP.FUNKTIONSTJANSTER_RP_DISPLAYNAME = $(Write-Host "Enter RP displayname (Example: Botkyrka Kommun)" -ForegroundColor Green -NoNewline; Read-Host).Trim()
        $AppSettingsKVP.FUNKTIONSTJANSTER_BANKID = $BankID
        $AppSettingsKVP.FUNKTIONSTJANSTER_FREJA = $FrejaEID

    }
    "2" {
                $AppSettingsKVP.SVENSKEIDENTITET_APIKEY = $(Write-Host "Enter main API key for Svensk E-identitet" -ForegroundColor Green -NoNewline; Read-Host).Trim()
                if($BankID -eq "true") {
                    $AppSettingsKVP.SVENSKEIDENTITET_BANKID = $BankID
                    $AppSettingsKVP.SVENSKEIDENTITET_BANKIDKEY = $(Write-Host "Enter BankID API key for Svensk E-identitet" -ForegroundColor Green -NoNewline; Read-Host).Trim()
                }
                if($FrejaEID -eq "true") {
                    $AppSettingsKVP.SVENSKEIDENTITET_FREJA = $FrejaEID
                    $AppSettingsKVP.SVENSKEIDENTITET_FREJAEIDKEY = $(Write-Host "Enter Freja eID API key for Svensk E-identitet" -ForegroundColor Green -NoNewline; Read-Host).Trim()
                }
    }
    "3" {
        Write-Host "Certificates needs to be uploaded, the configuration has to be done manually."
    }
}

$AppSettingsKVP.AUTH_TESTING = $(Write-Host "Go against eID PROD environemnt? (true/false, if false the application will go against BankID/FrejaeID TEST)" -ForegroundColor Green -NoNewline; Read-Host).Trim()
$AppSettingsKVP.TEAMS_INTEGRATED = $(Write-Host "Teams integrated mode? (true/false, if false the application will not work in Teams)" -ForegroundColor Green -NoNewline; Read-Host).Trim()
if($AppSettingsKVP.TEAMS_INTEGRATED -eq "true") {
    Write-Host "Teams Integrated mode requires AAD Application and authentication (see aad_app_deployment.ps1 in GitHub)"
    $AppSettingsKVP.AADAPP_CLIENT_ID = $(Write-Host "Application ID/Client ID: " -ForegroundColor Green -NoNewline; Read-Host).Trim()
    $AppSettingsKVP.AADAPP_CLIENT_SECRET = $(Write-Host "Client Secret: " -ForegroundColor Green -NoNewline; Read-Host).Trim()
    $AppSettingsKVP.AAD_TENANT_NAME = $(Write-Host "Tenant name (Check your .onmicrosoft.com domain, if: botkyrka.onmicrosoft.com this input should only be botkyrka): " -ForegroundColor Green -NoNewline; Read-Host).Trim()

    $AppSettingsKVP.SECURE_MEETINGS_ENABLED = $(Write-Host "Do you want to enable Secure Meetings? (true/false)" -ForegroundColor Green -NoNewline; Read-Host).Trim()
    if($AppSettingsKVP.SECURE_MEETINGS_ENABLED -eq "true") {
        $AppSettingsKVP.BASE_URL = $(Write-Host "Enter the base URL for the application, AAD apps does not allow .azurewebsites.net so you need to use a custom domain on the webapp (example: https://teamseid.municipality.se)" -ForegroundColor Green -NoNewline; Read-Host).Trim()
    }
}
ForEach($item in $WebApp.SiteConfig.AppSettings) {
    $AppSettingsKVP[$item.Name] = $item.Value   
}
Set-AzWebApp -AppSettings $AppSettingsKVP -Name $AppName -ResourceGroupName $ResourceGroupName
