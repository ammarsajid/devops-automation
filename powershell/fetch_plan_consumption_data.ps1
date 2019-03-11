$ServicePlanName= "mytestappserviceplan"
$resourcegroupname = "TESTRS"
$pathExportFile = "F:\Automation\" + $ServicePlanName + "_utilization" + (get-date).ToString('yyyyMMdd') + ".csv"

#Login-AzureRmAccount
Select-AzureRmSubscription -SubscriptionID "cadxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx9"

$ResourceId = "/subscriptions/$($(Get-AzureRMContext).Subscription.Id)/resourceGroups/$resourcegroupname/providers/Microsoft.Web/serverfarms/$ServicePlanName"
$TimeGrain = [TimeSpan]::Parse("00:01:00")

#$available_metrics = Get-AzureRmMetricDefinition -ResourceId $ResourceId

$endTime = [System.DateTime] (get-date)
$startTime = [System.DateTime] (get-date).AddDays(-32)

$metric1 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "CpuPercentage"
$metric2 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "MemoryPercentage"
$metric3 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "DiskQueueLength"
$metric4 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "HttpQueueLength"
$metric5 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "BytesReceived"
$metric6 = Get-AzureRmMetric -ResourceId $ResourceId -TimeGrain $TimeGrain -StartTime $startTime -EndTime $endTime -MetricName "BytesSent"



$metrics = @()
0..($metric1.Count - 1) | ForEach-Object {$metrics += @("$($metric1.Data[$_].TimeStamp)")}

$metrics = for ( $i = 0; $i -lt $metric1.Data.Count; $i++)
{
    New-Object -TypeName PSObject -Property @{
    TimeStamp = $metric1.Data[$i].TimeStamp
    CpuPercentage = $metric1.Data[$i].Average
    MemoryPercentage = $metric2.Data[$i].Average
    DiskQueueLength = $metric3.Data[$i].Average
    HttpQueueLength = $metric4.Data[$i].Average
    BytesReceived = $metric5.Data[$i].Total
    BytesSent = $metric6.Data[$i].Total
    }
}

$metrics | Export-Csv -Path $pathExportFile
$metrics| select -First 10