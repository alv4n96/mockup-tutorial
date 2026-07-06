<#
.SYNOPSIS
Generates a tutorial-only mock Git activity schedule.

.DESCRIPTION
By default this script creates or updates mock-history/*.md files, prints example
`git commit --date=...` commands, and stages the generated files with `git add`.

Use -CommitGenerated to create a normal current-date commit for the generated
files. Use -Push together with -CommitGenerated to push the current branch.

The script writes to the repository root mock-history/ folder by default, even
when the command is executed from another directory.
#>

param(
    [datetime]$StartDate = '2026-02-13',
    [datetime]$EndDate = '2026-07-06',
    [string]$TimezoneOffset = '+0700',
    [string]$OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'mock-history'),
    [switch]$NoStage,
    [switch]$CommitGenerated,
    [switch]$Push,
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

if ($Push -and -not $CommitGenerated) {
    throw 'Use -CommitGenerated with -Push so there is a commit to push.'
}

Write-Host '# Mock Git Activity Commands'
Write-Host '# Default mode creates mock-history/*.md files, prints commands, and stages generated files.'
Write-Host ''

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Add-Content -Path (Join-Path $OutputDirectory 'RUN_LOG.md') -Value ('- Generated at {0} with StartDate={1:yyyy-MM-dd}, EndDate={2:yyyy-MM-dd}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'), $StartDate, $EndDate)

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

        $path = Join-Path $OutputDirectory ($date.ToString('yyyy-MM-dd') + '.md')
        Add-Content -Path $path -Value ('- {0} {1}' -f $entry.DateText, $entry.Message)

        if ($Execute) {
            git add -- $path
            git commit --date=$entry.DateText -m $entry.Message
        }
    }

    Write-Host ''
}

if (-not $NoStage) {
    git add -- $OutputDirectory
    Write-Host ('Staged generated files: {0}' -f $OutputDirectory)
}

if ($CommitGenerated) {
    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'No staged generated changes to commit.'
    } else {
        git commit -m 'docs: update generated mock history'
    }
}

if ($Push) {
    $branch = git branch --show-current
    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw 'Cannot determine current branch for push.'
    }

    git push origin $branch
}
