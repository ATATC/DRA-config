param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $PromptParts
)

$prompt = ($PromptParts -join " ")

if ($prompt -match "(?i)passphrase|password") {
    Write-Output ""
    exit 0
}

if ($prompt -match "(?i)Duo two-factor|Passcode or option|Duo Push|select one of the following options") {
    Write-Output "1"
    exit 0
}

Write-Output ""
