<#
.SYNOPSIS
    Certbot Manual Cleanup Hook for STACKIT DNS Validation

.DESCRIPTION
    This script is invoked automatically by Certbot after the Let's Encrypt validation
    attempt (whether successful or not). It ensures the temporary TXT challenge
    records are removed from the STACKIT Verification Zone to maintain a clean DNS state.
#>

$Domain = $env:CERTBOT_DOMAIN
$ProjectId = $env:STACKIT_PROJECT_ID
$SaKeyPath = $env:DNS_SA_KEY_PATH
$VerifyZoneFQDN = $env:VERIFY_ZONE_FQDN

$ErrorActionPreference = "Stop"

$MissingVars = @()
if ([string]::IsNullOrWhiteSpace($Domain)) { $MissingVars += "CERTBOT_DOMAIN" }
if ([string]::IsNullOrWhiteSpace($ProjectId)) { $MissingVars += "STACKIT_PROJECT_ID" }
if ([string]::IsNullOrWhiteSpace($VerifyZoneFQDN)) { $MissingVars += "VERIFY_ZONE_FQDN" }

if ($MissingVars.Count -gt 0) {
    [Console]::Error.WriteLine(">>> [HOOK FATAL] Missing required environment variables from Certbot/Main Script: $($MissingVars -join ', ')")
    exit 1
}

try {
    Write-Output ">>> [CLEANUP] Starting DNS Cleanup Hook for: $Domain"
    $RecordName = $Domain

    # Suppress STACKIT CLI loading spinners from stderr to prevent Certbot logging errors
    $authOutput = & stackit auth activate-service-account --service-account-key-path "$SaKeyPath" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "STACKIT CLI Auth failed in Cleanup Hook." }

    $ZonesJson = & stackit dns zone list --project-id "$ProjectId" --output-format json 2>$null | ConvertFrom-Json
    $Zone = $ZonesJson | Where-Object { $_.dnsName -eq "$VerifyZoneFQDN" -or $_.dnsName -eq "$VerifyZoneFQDN." }
    if (-not $Zone) { throw "Verify Zone '$VerifyZoneFQDN' not found in STACKIT Project!" }
    $ZoneId = $Zone.id

    Write-Output ">>> [CLEANUP] Fetching record sets for zone $ZoneId..."
    $RecordsJson = & stackit dns record-set list --zone-id "$ZoneId" --project-id "$ProjectId" --output-format json 2>$null | ConvertFrom-Json

    # Account for FQDNs returned with or without a trailing dot
    $ExpectedNameWithDot = "$RecordName.$VerifyZoneFQDN."
    $ExpectedNameNoDot   = "$RecordName.$VerifyZoneFQDN"

    $TargetRecord = $RecordsJson | Where-Object {
        ($_.name -eq $ExpectedNameWithDot -or $_.name -eq $ExpectedNameNoDot) -and $_.type -eq "TXT"
    } | Select-Object -First 1

    if ($TargetRecord) {
        $RecordId = $TargetRecord.id
        Write-Output ">>> [CLEANUP] Found TXT record with ID '$RecordId'. Deleting..."

        # Suppress CLI auto-confirm warnings from stderr
        $deleteOutput = & stackit dns record-set delete "$RecordId" --zone-id "$ZoneId" --project-id "$ProjectId" --assume-yes 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to delete record: $deleteOutput"
        }
        Write-Output ">>> [CLEANUP] Done."
    } else {
        Write-Output ">>> [CLEANUP] WARNING: TXT record for '$RecordName' not found. It may have been already deleted."
    }

} catch {
    [Console]::Error.WriteLine(">>> [CLEANUP ERROR] $($_.Exception.Message)")
    exit 1
}
