$subscriptionID = "cadxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx9"
$DBserverName = "mytestsqlserver"
$databasename = "mytestdatabase"
$resourceGroup = "TESTRS" 
$edition = "Free"

# To log in to Azure Resource Manager
Login-AzureRmAccount

# Select a subscription to work with
Select-AzureRmSubscription -SubscriptionID $subscriptionID


#New-AzureRmSqlServer -ResourceGroupName $resourcegroupname `
#    -ServerName $servername `
#    -Location $location `
#    -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminlogin, $(ConvertTo-SecureString -String $password -AsPlainText -Force))


# Create a database
New-AzureRmSqlDatabase  -ResourceGroupName $resourceGroup -ServerName $DBserverName -DatabaseName $databasename -Edition $edition