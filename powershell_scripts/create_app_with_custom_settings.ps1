$subscriptionID = "565af59d-9511-40cd-811d-ce91ce902eb5"
$resourceGroup = "HMIS-TLX"
$appPlanName = "demo"
$webAppName = "test-app-auto"
$location = "NorthEurope"

Select-AzureRmSubscription -SubscriptionID $subscriptionID 

$webApp = New-AzureRmWebApp -ResourceGroupName $resourceGroup -Name $webAppName -AppServicePlan $appPlanName -Location $location

$webApp.SiteConfig.Use32BitWorkerProcess = $false
$webApp.SiteConfig.AlwaysOn = $true
$webApp.ClientAffinityEnabled = $false

$VDApp = New-Object Microsoft.Azure.Management.WebSites.Models.VirtualApplication
$VDApp.VirtualPath = "/app"
$VDApp.PhysicalPath = "site\wwwroot\app"
$VDApp.PreloadEnabled = "True"
$webApp.siteconfig.VirtualApplications.Add($VDApp)

$VDApp2 = New-Object Microsoft.Azure.Management.WebSites.Models.VirtualApplication
$VDApp2.VirtualPath = "/api"
$VDApp2.PhysicalPath = "site\wwwroot\api"
$VDApp2.PreloadEnabled = "True"
$webApp.siteconfig.VirtualApplications.Add($VDApp2)

$webApp | Set-azureRmWebApp