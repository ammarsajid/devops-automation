$subscriptionId = "cadxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx9"
$DBserverName = "mytestsqlserver"
$resourceGroupName = "TESTRS" 
$newDiskSize = "200" # in Gigabytes
$vmName = "test-VM"

Login-AzureRmAccount
 
# Select Azure Subscription
Select-AzureRmSubscription -SubscriptionID $subscriptionId

$vm = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName
 
Stop-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName

$vm.StorageProfile.DataDisks[0].DiskSizeGB = $newDiskSize
 
Update-AzureRmVM -ResourceGroupName $resourceGroupName -VM $vm
 
Start-AzureRmVM -ResourceGroupName $resourceGroupName -Name $vmName