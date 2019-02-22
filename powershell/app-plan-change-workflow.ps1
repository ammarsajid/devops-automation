workflow appapp-plan-change
{
inlineScript 
{
$connectionName = "AzureRunAsConnection"
		try
		{
    		# Get the connection "AzureRunAsConnection "
    		$servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         
		
    		"Logging in to Azure..."
    		Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
		}
		catch {                                 
    		if (!$servicePrincipalConnection)
    		{
        		$ErrorMessage = "Connection $connectionName not found."
        		throw $ErrorMessage
    		} else{
        		Write-Error -Message $_.Exception
        		throw $_.Exception
    		}
		}$cred = Get-AutomationPSCredential -Name 'accountautologin'
$account = Login-AzureRMAccount -credential $cred
        
$AzureSubscription = "112667f3-b281-4ede-a2f3-537bbe759911"
Select-AzureRmSubscription -SubscriptionID $AzureSubscription

$ResourceGroupName = "INFRATECHX"

$WebsiteName1 = "test-appplan"
$WebsiteName2 = "test-appplan1"
$WebsiteName3 = "test-appplan3"
$WebsiteName4 = "testappplan123"

$NewAppServicePlanName = "test123"


# $NewAppServicePlanName = "InternalConsumptionAppServicePlan"

 

$NewServerFarmId = "/subscriptions/" + $AzureSubscription + "/resourceGroups/" + $ResourceGroupName + "/providers/Microsoft.Web/serverfarms/" + $NewAppServicePlanName
$NewServerFarmId1 = "/subscriptions/" + $AzureSubscription + "/resourceGroups/" + $ResourceGroupName + "/providers/Microsoft.Web/serverfarms/" + $NewAppServicePlanName
$NewServerFarmId2 = "/subscriptions/" + $AzureSubscription + "/resourceGroups/" + $ResourceGroupName + "/providers/Microsoft.Web/serverfarms/" + $NewAppServicePlanName
$NewServerFarmId3 = "/subscriptions/" + $AzureSubscription + "/resourceGroups/" + $ResourceGroupName + "/providers/Microsoft.Web/serverfarms/" + $NewAppServicePlanName


 

write-host "trying to get website details"

$websiteResource = Get-AzureRMResource -ResourceType "microsoft.web/sites" -ResourceGroupName $ResourceGroupName -ResourceName $WebsiteName1
$websiteResource1 = Get-AzureRMResource -ResourceType "microsoft.web/sites" -ResourceGroupName $ResourceGroupName -ResourceName $WebsiteName2
$websiteResource2 = Get-AzureRMResource -ResourceType "microsoft.web/sites" -ResourceGroupName $ResourceGroupName -ResourceName $WebsiteName3
$websiteResource3 = Get-AzureRMResource -ResourceType "microsoft.web/sites" -ResourceGroupName $ResourceGroupName -ResourceName $WebsiteName4



$websiteResource.Properties.ServerFarmId = $NewServerFarmId
$websiteResource1.Properties.ServerFarmId = $NewServerFarmId1
$websiteResource2.Properties.ServerFarmId = $NewServerFarmId2
$websiteResource3.Properties.ServerFarmId = $NewServerFarmId3



 

write-host "trying to udpate website details"

$websiteResource | Set-AzureRmResource -Force
$websiteResource1 | Set-AzureRmResource -Force
$websiteResource2 | Set-AzureRmResource -Force
$websiteResource3 | Set-AzureRmResource -Force



Start-Sleep -s 15


Set-AzureRmAppServicePlan -Name "test321" -ResourceGroupName "INFRATECHX" -Tier Free
}
}