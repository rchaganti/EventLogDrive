using namespace Microsoft.PowerShell.SHiPS

[SHiPSProvider(UseCache = $false)]
class EventLogRoot : SHiPSDirectory
{
    #Static Member for the log types
    static [System.Collections.Generic.List``1[string[]]] $logMachineCollection
    
    # Default constructor
    EventLogRoot([string]$name):base($name)
    {
    }

    [object[]] GetChildItem()
    {
        $obj = @()

        if([EventLogRoot]::logMachineCollection)
        {
            [EventLogRoot]::logMachineCollection | ForEach-Object {
                $obj += [LogMachine]::new($_)
            }
        }
        else
        {
            $obj += [LogMachine]::new('Localhost')    
        }
        return $obj
    }
}

[SHiPSProvider()]
class LogMachine : SHiPSDirectory
{
    LogMachine([string]$name):base($name)
    {
        [EventLogRoot]::logMachineCollection += $this.name
    }

    [object[]] GetChildItem()
    {
        $obj = @()
        $logs = Get-EventLog -List -ComputerName $this.Name
        foreach ($log in $logs)
        {
            $obj += [EventLog]::new($log.log, $log)
        }
        return $obj
    }
}

[SHiPSProvider(UseCache = $true)]
class EventLog : SHiPSDirectory
{
    hidden [System.Diagnostics.EventLog] $LogData
    hidden [string] $machineName
    [long] $MaximumKilobytes
    [int] $MinimumRetentionDays
    [string] $LogDisplayName


    EventLog([string]$name, [System.Diagnostics.EventLog]$LogData):base($name)
    {
        $this.LogData = $LogData
        $this.MachineName = $LogData.MachineName
        $this.MaximumKilobytes = $LogData.MaximumKilobytes
        $this.MinimumRetentionDays = $LogData.MinimumRetentionDays
        $this.LogDisplayName = $LogData.LogDisplayName
    }

    [object[]] GetChildItem()
    {
        $obj = @()
        $sources = (Get-EventLog -LogName $this.name -ComputerName $this.MachineName).Source | Select-Object -Unique
        foreach ($source in $sources)
        {
            $obj += [EventLogSource]::new($source, $this.name, $this.MachineName)
        }
        return $obj
    }
}

[SHiPSProvider(UseCache = $true)]
class EventLogSource : SHiPSDirectory
{    
    hidden [string] $LogName
    hidden [string] $machineName

    EventLogSource([string]$name, [string] $LogName, [string]$MachineName):base($name)
    {
        $this.LogName = $LogName
        $this.MachineName = $MachineName
    }

    [object[]] GetChildItem()
    {
        $obj = @()
        $logEntries = Get-EventLog -LogName $this.LogName -Source $this.Name -ComputerName $this.MachineName
        foreach ($entry in $logEntries)
        {
            $obj += [EventLogEntry]::new($entry.EventID, $entry)
        }
        return $obj
    }
}

[SHiPSProvider(UseCache = $true)]
class EventLogEntry : SHiPSLeaf
{    
    hidden [object] $LogEntry
    [String] $Message
    [string] $UserName
    [datetime] $TimeGenerated
    [datetime] $TimeWritten
    [string] $EntryType

    EventLogEntry([string]$name, [object] $LogEntry):base($name)
    {
        $this.LogEntry = $LogEntry
        $this.UserName = $LogEntry.UserName
        $this.TimeGenerated = $LogEntry.TimeGenerated
        $this.TimeWritten = $LogEntry.TimeWritten
        $this.EntryType = $LogEntry.EntryType
        $this.Message = $LogEntry.Message
    }
}

function Get-LogMachine
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ComputerName
    )    

    [EventLogRoot]::logMachineCollection | Where-Object {$_ -eq $ComputerName}
}

function Connect-LogMachine
{
    [CmdletBinding()]
    param 
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ComputerName
    )

    if (-not (Get-LogMachine -ComputerName $ComputerName))
    {
        ([EventLogRoot]::logMachineCollection).Add($ComputerName)
    }
}