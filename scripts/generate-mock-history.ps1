<#
.SYNOPSIS
Generates a tutorial-only mock Git activity schedule.

.DESCRIPTION
By default this script prints example git commit commands using --date.
It is intended for tutorial material. Use -GenerateFiles to create
mock-history/*.md files without committing. It does not execute commits unless
-Execute is passed explicitly.

The generated schedule starts at 2026-02-13, ends at 2026-07-06,
skips Saturday and Sunday, and creates 3 to 6 sample commit commands
for each weekday.
#>

param(
    [datetime]$StartDate = '2026-02-13',
    [datetime]$EndDate = '2026-07-06',
    [string]$TimezoneOffset = '+0700',
    [switch]$GenerateFiles,
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'

$messages = @(
    'docs: prepare tutorial outline',
    'docs: add backend module notes',
    'docs: add database design notes',
    'docs: add frontend setup notes',
    'docs: add ui component notes',
    'docs: add testing checklist',
    'docs: refine production checklist',
    'docs: add troubleshooting notes'
)

function Get-CommitCountForDate {
    param([datetime]$Date)
    return 3 + (($Date.DayOfYear + $Date.Month) % 4)
}

function Get-MockCommitEntry {
    param(
        [datetime]$Date,
        [int]$Index,
        [string]$Message,
        [string]$TimezoneOffset
    )

    $hour = 9 + (($Index * 2 + $Date.Day) % 8)
    $minute = (($Date.DayOfYear + $Index * 11) % 60)
    $dateText = '{0} {1:D2}:{2:D2}:00 {3}' -f $Date.ToString('yyyy-MM-dd'), $hour, $minute, $TimezoneOffset

    [pscustomobject]@{
        DateText = $dateText
        Message = $Message
        Command = 'git commit --date="{0}" -m "{1}"' -f $dateText, $Message
    }
}

if ($EndDate -lt $StartDate) {
    throw 'EndDate must be greater than or equal to StartDate.'
}

Write-Host '# Mock Git Activity Commands'
Write-Host '# Tutorial output only. Default mode prints commands without executing them.'
Write-Host ''

for ($date = $StartDate.Date; $date -le $EndDate.Date; $date = $date.AddDays(1)) {
    if ($date.DayOfWeek -eq [DayOfWeek]::Saturday -or $date.DayOfWeek -eq [DayOfWeek]::Sunday) {
        continue
    }

    Write-Host ('## {0}' -f $date.ToString('yyyy-MM-dd dddd', [Globalization.CultureInfo]::InvariantCulture))

    $count = Get-CommitCountForDate -Date $date
    for ($i = 0; $i -lt $count; $i++) {
        $message = $messages[($date.DayOfYear + $i) % $messages.Count]
        $entry = Get-MockCommitEntry -Date $date -Index $i -Message $message -TimezoneOffset $TimezoneOffset
        Write-Host $entry.Command

        if ($GenerateFiles -or $Execute) {
            $path = Join-Path 'mock-history' ($date.ToString('yyyy-MM-dd') + '.md')
            New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
            Add-Content -Path $path -Value ('- {0} {1}' -f $entry.DateText, $entry.Message)
        }

        if ($Execute) {
            git add $path
            git commit --date=$entry.DateText -m $entry.Message
        }
    }

    Write-Host ''
}

