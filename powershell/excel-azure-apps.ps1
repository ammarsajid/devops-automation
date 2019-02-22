Login-AzureRmAccount
$subscriptionId = "123xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx4"
Select-AzureRmSubscription -SubscriptionID $subscriptionId
# Create the Excel doc
$Excel = New-Object -ComObject Excel.Application
$Excel.Visible = $True
$chartType = "microsoft.office.interop.excel.xlChartType" -as [type]
# after closing excel pop up

$workbook = $excel.workbooks.add()

$workbook.WorkSheets.item(1).Name = "Subscription1"

$Worksheet = $workbook.WorkSheets.Item("Subscription1")

$xlFixedFormat = [Microsoft.Office.Interop.Excel.XlFileFormat]::xlWorkbookDefault


# Now, name the columns
$x = 2

$Worksheet.cells.item(1,1) = "SiteName"

$Worksheet.cells.item(1,2) = "State"

$Worksheet.cells.item(1,3) = "HostNames"

$webapps = Get-AzureRmWebApp
foreach ($webapp in $webapps)

{

$Worksheet.cells.item($x,1) = $webapp.SiteName

$Worksheet.cells.item($x,2) = $webapp.State



#$Worksheet.cells.item($x,3) = $webapp.HostNames
For ($i=0; $i -le $webapp.HostNames.Count; $i++)
{
       $Worksheet.cells.item($x,3+$i) = $webapp.HostNames[$i]
}

$x++

}
$range = $Worksheet.usedRange

$range.EntireColumn.AutoFit()