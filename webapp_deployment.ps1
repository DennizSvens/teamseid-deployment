$AppName = $(Write-Host "Web App Name (example: municipalityeid)" -ForegroundColor Green -NoNewline; Read-Host).Trim()
$ResourceGroupName = $(Write-Host "Resource Group Name (Will create a new resource group if not created)" -ForegroundColor Green -NoNewline; Read-Host).Trim()


$GitHubRepo="https://github.com/DennizSvens/teams-app-eid"
$Location="West Europe"

if(!Get-AzResourceGroup $ResouceGroupName) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $location
}
New-AzAppServicePlan -Name $AppName -Location $location -ResourceGroupName $ResourceGroupName -Tier Free
New-AzWebApp -Name $AppName -Location $location -AppServicePlan $AppName -ResourceGroupName $ResouceGroupName
$PropertiesObject = @{
    repoUrl = "$GitHubRepo";
    branch = "master";
    isManualIntegration = "true";
}
Set-AzResource -Properties $PropertiesObject -ResourceGroupName myResourceGroup -ResourceType Microsoft.Web/sites/sourcecontrols -ResourceName $AppName/web -ApiVersion 2015-08-01 -Force
