
param([string]$Source_Server, [string]$Source_Username, [string]$Source_Password,[string]$source_path,[string]$restore_db_name,[string]$Target_Server, [string]$Target_Username, [string]$Target_Password)
#$source = C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Backup\'
$RunId = [guid]::NewGuid()
$Global:S3BucketName = "inmarsat-$RunId"


function Execute-SqlQuery-Source
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
$Query1 = "BACKUP DATABASE $restore_db_name TO DISK = N'$source_path\$restore_db_name.bak' "
Write-Host "$Query1"
$QueryResult = Execute-SqlQuery-Source -Server $Source_Server -Database $Database -Username $Source_Username -Password $Source_Password -Query $Query1;
Set-Location $source_path
Write-Host "the source is $source_path"
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


function Execute-SqlQuery-Target
(
[string]$Server, 
[string]$Database1, 
[string]$Username, 
[string]$Password, 
#[Bool]$UseWindowsAuthentication = $False, 
[string]$Query2, 
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
 $Command.CommandText = $Query2;
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

$Database1 = "master"
#Write-Host " vars: $Server , $Username,$source,$restore_db_name"
#$Query = "exec msdb.dbo.rds_restore_database " + @restore_db_name + "='kranti225'" +,+ @s3_arn_to_restore_from +"='arn:aws:s3:::$S3BucketName/adventure-works-2008r2-lt.bak'"
$Query2 = "exec msdb.dbo.rds_restore_database @restore_db_name =$restore_db_name,@s3_arn_to_restore_from='arn:aws:s3:::$($S3BucketName)/*'"
Write-Host "executable query is $Query2"
$QueryResult = Execute-SqlQuery-Target -Server $Target_Server -Database1 $Database1 -Username $Target_Username -Password $Target_Password -Query2 $Query2;
Write-Host "conn: $QueryResult"
#$QueryResult | Format-Table;
 #   }

#./backup_restore_script.ps1 -Source_Server ec2-54-166-249-219.compute-1.amazonaws.com -Source_Username sa -Source_Password sqlserver -source_path C:\Backup\ -restore_db_name kranthi -Target_Server sqlserver.cmha3vurzm78.us-east-1.rds.amazonaws.com -Target_Username sqlserver -Target_Password sqlserver



