#Get launch parameters
Param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNull()]
    [string]$database,
    [string]$username
)
#Clear built in error variable. Used for error logs later.
$error.clear()

#check for pgpass.conf
Function Test-Pgpass {
    #Get path from registry
    $pgpasspath = (Get-ItemProperty -Path HKLM:\SOFTWARE\Amarex\PostgreSQL).pgpasspath
    $temp = $(Try { Test-path -Path $pgpasspath } catch { $false }) #returns false if no path($null) and true if path exists.
    Out-File -InputObject $error -FilePath $errorlog -Append
    #Check if pgpass.conf exists and if it contains the needed user account; otherwise return that the file is blank.
    if ($temp -eq $false) {
        Out-File -InputObject "Error: Required PgpassPath key not found in registry!" -FilePath $errorlog -Append
    }
    Elseif ((Get-Content -Path $pgpasspath).Contains("postgres") -eq $true ) {
        #check if pgpass.conf contains text.
        Out-File -InputObject "PgpassPath key found in registry! Password in pgpass.conf will be used to run commands." -FilePath $errorlog -Append
    }
    else {
        Out-File -InputObject "PgpassPath key found in registry!, but pgpass.conf is blank." -FilePath $errorlog -Append
    }
}
#Function to make each run distinguishable in error log.
Function New-Run {
    #Write full time and date to error log.
    Out-File -InputObject "Starting task passwd_timestamp on:" -FilePath $errorlog -Append
    Get-Date | Out-File -FilePath $errorlog -Append
}

If (Test-Path 'C:\Program Files\PostgreSQL') {
    $psqlExe = 'C:\Program Files\PostgreSQL\9.5\bin\psql.exe'
}
Else {
    $psqlExe = 'C:\Program Files (x86)\PostgreSQL\8.4\bin\psql.exe'
}

$date = Get-Date -UFormat %Y-%m-%d
$errorlog = "C:\OC\Tomcat_PROD\logs\passwd_timestamp.$date.txt"

#Update database with new password set date.
$updatecmd = "UPDATE user_account SET passwd_timestamp = '$date' WHERE user_name = '$username'"

New-Run
Test-Pgpass
Out-File -InputObject "Changing passwd_timestamp date in DATABASE:$database for USER:$username to DATE:$date. `r`nPostgreSQL will print UPDATE 1 on successful command execution." -FilePath $errorlog -Append
& $psqlExe -U postgres -d $database -c $updatecmd | Out-File $errorlog -Append

#Send email notification of job completion
$MailFrom, $MailServer, $MailPort = 'from', 'mailserver', '25'
$MailTo = @('email')
$MailSubject, $MailBody = "$username in $database password expiration date updated", "$username passwd_timestamp date changed to $date. See attached log to verify success or failure."
Send-MailMessage -From $MailFrom -To $MailTo -Subject $MailSubject -Body $MailBody -SmtpServer $MailServer -Port $MailPort -Attachments $errorlog