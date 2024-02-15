# Zabbix Agent 2 for Windows Low-Privileged Installer Script

An entirely unsupported, use at your own risk custom installation script
for the Windows Zabbix Agent 2, which reconfigures the service to run with
NT AUTHORITY\LocalService "minimum privileged account"
<https://learn.microsoft.com/en-us/windows/win32/services/localservice-account>
and which follows Zabbix best practices:
<https://www.zabbix.com/documentation/current/en/manual/installation/requirements/best_practices>