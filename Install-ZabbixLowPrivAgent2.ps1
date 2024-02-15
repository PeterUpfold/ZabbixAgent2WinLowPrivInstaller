#
# Install-ZabbixLowPrivAgent2
#
# An entirely unsupported, use at your own risk custom installation script
# for the Windows Zabbix Agent 2, which reconfigures the service to run with
# NT AUTHORITY\LocalService "minimum privileged account"
# <https://learn.microsoft.com/en-us/windows/win32/services/localservice-account>
# and which follows Zabbix best practices:
# <https://www.zabbix.com/documentation/current/en/manual/installation/requirements/best_practices>
#
#
# Copyright (C) 2024 Peter Upfold
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with
# this program. If not, see <https://www.gnu.org/licenses/>. 
#
$ErrorActionPreference="Stop"

$serviceName = "Zabbix Agent 2"
$msiPath = "zabbix-agent2.msi"
$serviceAccount = "NT AUTHORITY\LocalService" # The account used must have "Log on as a service" right. LocalService does by default
$opensslPath = "C:\openssl-64bit" # we revoke write access to this folder by normal users as per the Zabbix Agent hardening guide
$msiLogFile = "$($env:TEMP)\zabbix-agent2-msi.log"
$servers = "127.0.0.1" # comma separated IP addresses of your Zabbix server(s) and proxies
$confPath = "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf"

# The log file must be set to a path that NT AUTHORITY\LocalService can write to,
# or the service will not start. Alternatively, do your own config file handling, but
# ensure that the log file path will be writable by the user. It can't tell you why
# the service won't start if the reason for it is that it can't write to the log file!
$logOrig = "C:\\Program Files\\Zabbix Agent 2\\zabbix_agent2.log" # default logfile string (escaped backslashes)
$logReplace = "C:\Windows\ServiceProfiles\LocalService\zabbix_agent2.log" # replaced logfile string (plain)

# Install the MSI
$proc = Start-Process -FilePath "msiexec.exe" -ArgumentList @(
    "/l*v",
    $msiLogFile,
    "/i",
    $msiPath,
    "/qn",
    "SERVER=$servers"
) -PassThru -Wait

# Check the MSI installed
if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
    Write-Error "MSI installation failed with exit code $($proc.ExitCode). See $msiLogFile for details."
    exit $proc.ExitCode
}

# Update the config file with the new log path
$cfgFileContent = Get-Content -Path $confPath
$cfgFileNewContent = $cfgFileContent -replace $logOrig, $logReplace
$cfgFileNewContent | Set-Content -Path $confPath

# Set the account that runs the service
$serviceWMI = Get-WmiObject -Class Win32_Service -Filter "name='$serviceName'"

#ref: https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/change-method-in-class-win32-service 
# uint32 Change(
#   [in] string  DisplayName,
#   [in] string  PathName,
#   [in] uint32  ServiceType,
#   [in] uint32  ErrorControl,
#   [in] string  StartMode,
#   [in] boolean DesktopInteract,
#   [in] string  StartName,
#   [in] string  StartPassword,
#   [in] string  LoadOrderGroup,
#   [in] string  LoadOrderGroupDependencies[],
#   [in] string  ServiceDependencies[]
# );
# To use a different account, you may also need to provide
# a password argument.
$serviceWMI.Change($null, $null, $null, $null, $null, $null, $serviceAccount, $null, $null, $null, $null)

# Revoke write access to OpenSSL configuration in Windows, only if it does not exist already
#ref: https://www.zabbix.com/documentation/current/en/manual/installation/requirements/best_practices
if (-not (Test-Path $opensslPath)) {
    New-Item -ItemType Directory $opensslPath

    # break inheritance of permissions
    icacls.exe "$opensslPath" /inheritance:r

    # add full control for SYSTEM and BUILTIN\Admininstrators
    icacls.exe "$opensslPath" /grant "BUILTIN\Administrators:(OI)(CI)(F)"
    icacls.exe "$opensslPath" /grant "NT AUTHORITY\SYSTEM:(OI)(CI)(F)"

    # add read-only ACE for Users
    icacls.exe "$opensslPath" /grant "BUILTIN\Users:(OI)(CI)(RX)"
}

# Restart service to apply changes
Restart-Service $serviceName