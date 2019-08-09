

<#

parameters which needs to be dynamically given

path,Akey,Skey,awsregion,serverinstancename,restore_db_name,username,paswword,profilename,profileloaction

#>
param([string]$Server, [string]$Username, [string]$Password,[string]$source,[string]$restore_db_name)
#$source = 'C:\backup'
$RunId = [guid]::NewGuid()
$Global:S3BucketName = "sqlserverbackup225-$RunId"


function Execute-SqlQuery
(
[string]$Server, 
[string]$Database, 
[string]$Username, 
[string]$Password, 
#[Bool]$UseWindowsAuthentication = $False, 
[string]$Query, 
[int]$CommandTimeout=0
 )
{
 #Create Connection string
 $ConnectionString = "Server=$Server; Database=$Database; User ID=$username; Password=$password;"
 #If ($UseWindowsAuthentication) { $ConnectionString += "Trusted_Connection=Yes; Integrated Security=SSPI;" } else { $ConnectionString += "User ID=$username; Password=$password;" }
 
 #Connect to database
 $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString);
 Write-Host "conn : $ConnectionString"
 $Connection.Open();

 #Create query object
 $Command = $Connection.CreateCommand();
 $Command.CommandText = $Query;
 $Command.CommandTimeout = $CommandTimeout;

 #Exucute query
 $SqlDataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $Command;
 $DataSet = New-Object System.Data.DataSet;
 $SqlDataAdapter.Fill($DataSet) | Out-Null;

 #Return result
 If ($DataSet.Tables[0] -ne $Null) { $Table = $DataSet.Tables[0] }
 ElseIf ($table.Rows.Count -eq 0) { $Table = New-Object System.Collections.ArrayList }
 $Connection.Close();
 return $Table;
}



function upload_to_s3
{

#Initialize-AWSDefaultConfiguration -AccessKey $AccessKey -SecretKey $SecretKey -AWSRegion $AWSRegion
New-S3Bucket -BucketName $S3BucketName -CannedACLName "bucket-owner-full-control" 
Set-S3BucketEncryption -BucketName $S3BucketName -ServerSideEncryptionConfiguration_ServerSideEncryptionRule @{ServerSideEncryptionByDefault = @{ServerSideEncryptionAlgorithm = "AES256" } } 

}
upload_to_s3 
Set-Location $source
$files = Get-ChildItem '*.bak' | Select-Object -Property Name
try {
   if(Test-S3Bucket -BucketName $S3BucketName) {
      foreach($file in $files) {
         if(!(Get-S3Object -BucketName $S3BucketName -Key $file.Name)) { ## verify if exist
            Write-Host "Copying file : $file "
            Write-S3Object -BucketName $S3BucketName -File $file.Name -Key $file.Name -CannedACLName private 
            
         } 
      }
   } Else {
      Write-Host "The bucket $bucket does not exist."
   }
} catch {
   Write-Host "Error uploading file $file"
}

#main -Server $Server -Username $Username -Password $Password
#function main {


$Database = "master"
Write-Host " vars: $Server , $Username,$source,$restore_db_name"
#$Query = "exec msdb.dbo.rds_restore_database " + @restore_db_name + "='kranti225'" +,+ @s3_arn_to_restore_from +"='arn:aws:s3:::$S3BucketName/adventure-works-2008r2-lt.bak'"
$Query = "exec msdb.dbo.rds_restore_database @restore_db_name =$restore_db_name,@s3_arn_to_restore_from='arn:aws:s3:::$($S3BucketName)/*'"
Write-Host "executable query is $Query"
$QueryResult = Execute-SqlQuery -Server $Server -Database $Database -Username $Username -Password $Password -Query $Query;
Write-Host "conn: $QueryResult"
#$QueryResult | Format-Table;
 #   }
 

#./MigrateSQLServerToEC2Windows_v1.ps1 -Server sqlserver2016.cmha3vurzm78.us-east-1.rds.amazonaws.com -Username sa -Password Test1234 -restore_db_name adventureworks369



