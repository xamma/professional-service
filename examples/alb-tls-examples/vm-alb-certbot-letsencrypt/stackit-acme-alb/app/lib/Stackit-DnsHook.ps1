<#
.SYNOPSIS
    Certbot Manual Auth Hook for STACKIT DNS Validation

.DESCRIPTION
    This script is invoked automatically by Certbot during the DNS-01 challenge.
    It takes the validation token provided by Let's Encrypt and creates a temporary
    TXT record in a designated STACKIT Verification Zone (Delegation Mode).
#>

# Certbot automatically injects these environment variables
$Domain = $env:CERTBOT_DOMAIN
$ValidationToken = $env:CERTBOT_VALIDATION

# Variables passed down from the Main Orchestrator script
$ProjectId = $env:STACKIT_PROJECT_ID
$SaKeyPath = $env:DNS_SA_KEY_PATH
$VerifyZoneFQDN = $env:VERIFY_ZONE_FQDN

$ErrorActionPreference = "Stop"

# Ensure all required inputs are present
$MissingVars = @()
if ([string]::IsNullOrWhiteSpace($Domain)) { $MissingVars += "CERTBOT_DOMAIN" }
if ([string]::IsNullOrWhiteSpace($ProjectId)) { $MissingVars += "STACKIT_PROJECT_ID" }
if ([string]::IsNullOrWhiteSpace($VerifyZoneFQDN)) { $MissingVars += "VERIFY_ZONE_FQDN" }

if ($MyInvocation.MyCommand.Name -match "DnsHook" -and [string]::IsNullOrWhiteSpace($ValidationToken)) {
    $MissingVars += "CERTBOT_VALIDATION"
}

if ($MissingVars.Count -gt 0) {
    # We use [Console]::Error.WriteLine to ensure Certbot directly catches fatal hook errors
    [Console]::Error.WriteLine(">>> [HOOK FATAL] Missing required environment variables from Certbot/Main Script: $($MissingVars -join ', ')")
    exit 1
}

try {
    Write-Output ">>> [HOOK] Starting DNS Auth Hook for: $Domain"
    $RecordName = $Domain

    # Authenticate via STACKIT CLI using the dedicated DNS Service Account.
    # CRITICAL: We redirect stream 2 (`2>&1`) to a variable. The CLI may output loading spinners
    # to stderr, which Certbot falsely interprets as a critical script failure.
    $authOutput = & stackit auth activate-service-account --service-account-key-path "$SaKeyPath" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "STACKIT CLI Auth failed in Hook: $authOutput"
    }

    # Fetch the ID of the Verification Zone.
    # `2>$null` suppresses CLI warnings to ensure ConvertFrom-Json receives a clean JSON payload.
    $ZonesJson = & stackit dns zone list --project-id "$ProjectId" --output-format json 2>$null | ConvertFrom-Json
    $Zone = $ZonesJson | Where-Object { $_.dnsName -eq "$VerifyZoneFQDN" -or $_.dnsName -eq "$VerifyZoneFQDN." }
    if (-not $Zone) {
        throw "Verify Zone '$VerifyZoneFQDN' not found in STACKIT Project!"
    }
    $ZoneId = $Zone.id

    Write-Output ">>> [HOOK] Creating TXT Record: '$RecordName' in Zone: '$VerifyZoneFQDN'"
    $QuotedToken = "`"$ValidationToken`""

    # Create the TXT record. Stream 2 is captured again to suppress CLI auto-confirm warnings.
    $createOutput = & stackit dns record-set create --zone-id "$ZoneId" --name "$RecordName" --type "TXT" --record "$QuotedToken" --project-id "$ProjectId" --assume-yes 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create TXT record: $createOutput"
    }

    # Let's Encrypt requires time for the DNS entry to propagate across global nameservers
    Write-Output ">>> [HOOK] Sleeping 30 seconds to allow DNS propagation..."
    Start-Sleep -Seconds 30

} catch {
    [Console]::Error.WriteLine(">>> [HOOK ERROR] $($_.Exception.Message)")
    exit 1
}
