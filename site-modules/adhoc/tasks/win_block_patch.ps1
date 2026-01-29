[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [String]$kbnumber
)

$result = @{
    status = "unknown"
    kb_number = $kbnumber
    message = ""
    details = @{}
}

try {
    # Remove 'KB' prefix if present
    $kbnumber = $kbnumber -replace '^KB', ''
    $result.kb_number = $kbnumber

    # Suppress all confirmation prompts
    $ConfirmPreference = 'None'
    $ErrorActionPreference = 'Stop'

    # Hide the update using COM API to avoid prompts
    $Session = New-Object -ComObject Microsoft.Update.Session
    $Searcher = $Session.CreateUpdateSearcher()
    $Results = $Searcher.Search("IsInstalled=0 or IsInstalled=1")
    
    $Found = $false
    foreach ($Update in $Results.Updates) {
        if ($Update.KBArticleIDs -contains $kbnumber) {
            $Update.IsHidden = $true
            $Found = $true
            $result.status = "success"
            $result.message = "KB${kbnumber} has been successfully hidden"
            $result.details.title = $Update.Title
            $result.details.is_hidden = $true
            break
        }
    }
    
    if (-not $Found) {
        $result.status = "error"
        $result.message = "KB${kbnumber} was not found in available or installed updates"
    }
}
catch {
    $result.status = "error"
    $result.message = "An exception occurred while blocking KB${kbnumber}"
    $result.details.exception = $_.Exception.Message
}

# Output as JSON
$result | ConvertTo-Json -Depth 3