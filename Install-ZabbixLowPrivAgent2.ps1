$ErrorActionPreference="Stop"

$serviceName = "Zabbix Agent 2"
$msiPath = "zabbix-agent2.msi"
$serviceAccount = "NT AUTHORITY\LocalService" # The account used must have "Log on as a service" right. LocalService does by default
$opensslPath = "C:\openssl-64bit" # we revoke write access to this folder by normal users as per the Zabbix Agent hardening guide

# Install the MSI
$proc = Start-Process -FilePath "msiexec.exe" -ArgumentList @(
    "/l*v",
    $msiLogFile,
    "/i",
    $msiPath,
    "/qn",
    "HOSTNAME=$hostname",
    "SERVER=$servers"
) -PassThru -Wait

if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
    Write-Error "MSI installation failed with exit code $($proc.ExitCode). See $msiLogFile for details."
    exit $proc.ExitCode
}

# The log file must be set to a path that NT AUTHORITY\LocalService can write to


# Set the account that runs the service. You may also need to provide the password argument for
# an account that is not a builtin.
$serviceWMI = Get-WmiObject -Class Win32_Service -Filter "name='$serviceName'"
$serviceWMI.Change($null, $null, $null, $null, $null, $null, $serviceAccount, $null, $null, $null, $null)

# Revoke write access to SSL configuration in Windows
if (-not )


# Restart service to apply changes
Restart-Service $serviceName