<#
.SYNOPSIS
    STACKIT ALB Certificate Auto-Renewal Orchestrator (PoC)

.DESCRIPTION
    This script automates the renewal of Let's Encrypt certificates for a STACKIT Application Load Balancer.
    It identifies expiring certificates, triggers Certbot to perform a DNS-01 challenge, uploads the
    renewed certificates to the STACKIT Certificate Manager, and patches the ALB configuration.

    This is intended as a Proof of Concept (PoC) baseline for CI/CD integration.
    It supports passing Service Account keys as Base64 environment variables to avoid persisting secrets on disk.
#>

param (
    # Core Infrastructure
    [string] $ProjectId = $env:PROJECT_ID,
    [string] $RegionId = $(if ($env:REGION_ID) { $env:REGION_ID } else { "eu01" }),
    [string] $AlbName = $env:ALB_NAME,

    # Optional filtering: Only renew domains listed here
    [string[]] $DomainWhitelist = @(),

    # Paths & Credentials
    [string] $CertbotLive = $(if ($env:CERTBOT_LIVE_PATH) { $env:CERTBOT_LIVE_PATH } else { "/etc/letsencrypt/live" }),
    [string] $DNS_SAKeyPath = $(if ($env:DNS_SA_KEY_PATH) { $env:DNS_SA_KEY_PATH } else { "$PSScriptRoot/keys/dns-validator-sa.json" }),
    [string] $ALB_SAKeyPath = $(if ($env:ALB_SA_KEY_PATH) { $env:ALB_SA_KEY_PATH } else { "$PSScriptRoot/keys/alb-manager-sa.json" }),

    # Execution Modifiers
    [bool] $SkipCertbot = $(if ($env:SKIP_CERTBOT -match '^(true|1|yes)$') { $true } else { $false }),
    [int] $DaysWarning = $(if ($env:DAYS_WARNING) { [int]$env:DAYS_WARNING } else { 30 }),

    # API Endpoints
    [string] $AlbBaseUrl = $(if ($env:ALB_BASE_URL) { $env:ALB_BASE_URL } else { "https://alb.api.stackit.cloud/v2" }),
    [string] $CertBaseUrl = $(if ($env:CERT_BASE_URL) { $env:CERT_BASE_URL } else { "https://certificates.api.stackit.cloud/v2" }),
    [string] $AcmeServer = $(if ($env:ACME_SERVER) { $env:ACME_SERVER } else { "https://acme-staging-v02.api.letsencrypt.org/directory" }),

    # Advanced: CNAME Delegation Mode configuration
    [bool] $UseChallengeDelegation = $(if ($env:USE_CHALLENGE_DELEGATION -match '^(true|1|yes)$') { $true } else { $false }),
    [string] $VerifyZoneFQDN = $env:VERIFY_ZONE_FQDN
)

$ErrorActionPreference = "Stop"
Write-Output "=== STACKIT ALB Certificate Auto-Renewal Pipeline ==="

# Parse whitelist from environment if not provided via parameter
if ($DomainWhitelist.Count -eq 0 -and $env:DOMAIN_WHITELIST) {
    $DomainWhitelist = $env:DOMAIN_WHITELIST -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
}

$Config = @{
    ProjectId              = $ProjectId
    RegionId               = $RegionId
    AlbName                = $AlbName
    DomainWhitelist        = $DomainWhitelist
    CertbotLive            = $CertbotLive
    DNS_SAKeyPath          = $DNS_SAKeyPath
    ALB_SAKeyPath          = $ALB_SAKeyPath
    SkipCertbot            = $SkipCertbot
    DaysWarning            = $DaysWarning
    AlbBaseUrl             = $AlbBaseUrl
    CertBaseUrl            = $CertBaseUrl
    AcmeServer             = $AcmeServer
    UseChallengeDelegation = $UseChallengeDelegation
    VerifyZoneFQDN         = $VerifyZoneFQDN
}

# --- PRE-FLIGHT CHECKS ---
Write-Output "`n>>> [INIT] Starting pre-flight checks..."

# CI/CD Integration: Decode Base64 encoded Service Account keys injected via Environment Variables.
# This avoids storing physical JSON files in the repository or mounting them insecurely.
if ($env:ALB_SA_KEY_B64) {
    Write-Output "  [INFO] Decoding ALB Service Account from Base64 variable..."
    $albBytes = [System.Convert]::FromBase64String($env:ALB_SA_KEY_B64.Trim())
    $Config.ALB_SAKeyPath = Join-Path ([System.IO.Path]::GetTempPath()) "alb-sa.json"
    [System.IO.File]::WriteAllBytes($Config.ALB_SAKeyPath, $albBytes)
}

if ($env:DNS_SA_KEY_B64) {
    Write-Output "  [INFO] Decoding DNS Service Account from Base64 variable..."
    $dnsBytes = [System.Convert]::FromBase64String($env:DNS_SA_KEY_B64.Trim())
    $Config.DNS_SAKeyPath = Join-Path ([System.IO.Path]::GetTempPath()) "dns-sa.json"
    [System.IO.File]::WriteAllBytes($Config.DNS_SAKeyPath, $dnsBytes)
}

# Verify that key files exist (either provided directly or decoded above)
if (-not (Test-Path $Config.DNS_SAKeyPath)) {
    Write-Error "[FATAL] DNS Service Account Key missing at $($Config.DNS_SAKeyPath)"
    exit 1
}
if (-not (Test-Path $Config.ALB_SAKeyPath)) {
    Write-Error "[FATAL] ALB Service Account Key missing at $($Config.ALB_SAKeyPath)"
    exit 1
}

if ($Config.UseChallengeDelegation -and [string]::IsNullOrWhiteSpace($Config.VerifyZoneFQDN)) {
    Write-Error "[FATAL] Challenge Delegation is enabled, but VERIFY_ZONE_FQDN is empty!"
    exit 1
}

# Import helper functions
. "$PSScriptRoot/lib/Get-StackitAlbCertStatus_CLI.ps1"
. "$PSScriptRoot/lib/StackitHelper_CLI.ps1"
Write-Output "[OK] Pre-flight checks passed."

# --- STEP 1: AUTHENTICATION ---
Write-Output "`n>>> [STEP 1] Activating STACKIT CLI Service Account (ALB Scope)..."
& stackit auth activate-service-account --service-account-key-path $Config.ALB_SAKeyPath
if ($LASTEXITCODE -ne 0) { throw "Failed to activate STACKIT CLI Service Account for ALB operations." }
Write-Output "[OK] STACKIT CLI successfully authenticated."

# --- STEP 2: STATUS CHECK ---
# Query the ALB configuration to map domains to active certificates and calculate expiration
Write-Output "`n>>> [STEP 2] Fetching ALB configuration and certificate status..."
$status = Get-StackitAlbCertStatus -ProjectId $Config.ProjectId -RegionId $Config.RegionId -AlbName $Config.AlbName -Whitelist $Config.DomainWhitelist -DaysWarning $Config.DaysWarning -AlbBaseUrl $Config.AlbBaseUrl -CertBaseUrl $Config.CertBaseUrl

$allCerts = @($status.certificates)
$toRenew  = @($allCerts | Where-Object { $_.shouldReplace -eq $true })
$healthyCerts = @($allCerts | Where-Object { $_.shouldReplace -eq $false })

Write-Output "[INFO] Evaluated a total of $($allCerts.Count) active certificate(s) on ALB '$($Config.AlbName)'."

# Sub-Check 2a: Warn if a whitelisted domain is missing from the ALB configuration
if ($Config.DomainWhitelist.Count -gt 0) {
    $albDomains = $allCerts.domain
    foreach ($wlDomain in $Config.DomainWhitelist) {
        if ($albDomains -notcontains $wlDomain) {
            Write-Warning "  [SKIP] Domain '$wlDomain' is on the whitelist, but is NOT configured on the ALB. Skipping..."
        }
    }
}

# Sub-Check 2b: Log healthy certificates that do not require renewal yet
if ($healthyCerts.Count -gt 0) {
    foreach ($hc in $healthyCerts) {
        Write-Output "  [SKIP] Certificate for '$($hc.domain)' is healthy (Expires in $($hc.daysUntilExpiry) days). No action required."
    }
}

if ($toRenew.Count -eq 0) {
    Write-Output "`n[RESULT] All targeted certificates are healthy and up to date. No renewals required."
    Write-Output "=== Workflow Completed SUCCESSFULLY ==="
    exit 0
}

# --- STEP 3 & 4: RENEWAL LOOP ---
Write-Output "`n>>> [STEP 3] Starting renewal process for $($toRenew.Count) certificate(s)..."

$WorkflowHasErrors = $false

foreach ($cert in $toRenew) {
    Write-Output "`n--------------------------------------------------------"
    Write-Output "[*] Target Domain  : $($cert.domain)"
    Write-Output "[*] Expiring Cert  : $($cert.certificateId)"
    Write-Output "--------------------------------------------------------"

    $certbotSuccess = $false
    $domainPath    = Join-Path $Config.CertbotLive $cert.domain
    $fullchainPath = Join-Path $domainPath "fullchain.pem"
    $privkeyPath   = Join-Path $domainPath "privkey.pem"

    if (-not $Config.SkipCertbot) {
        Write-Output "  -> [Action] Triggering Certbot ACME DNS-01 challenge..."

        # --- CERTBOT EXTERNAL LOG BOUNDARY ---
        Write-Output ""
        Write-Output "  v===================== CERTBOT OUTPUT =====================v"

        if ($Config.UseChallengeDelegation) {
            Write-Output "  -> [INFO] Mode: CNAME Delegation Hooks (Verify Zone: $($Config.VerifyZoneFQDN))"

            # Export variables required by the child processes (the PowerShell Hook scripts)
            $env:STACKIT_PROJECT_ID = $Config.ProjectId
            $env:DNS_SA_KEY_PATH = $Config.DNS_SAKeyPath
            $env:VERIFY_ZONE_FQDN = $Config.VerifyZoneFQDN

            $PSExe = if ($PSVersionTable.PSVersion.Major -ge 6) { "pwsh" } else { "powershell" }

            $AuthHookPath = Join-Path $PSScriptRoot "lib\Stackit-DnsHook.ps1"
            $CleanupHookPath = Join-Path $PSScriptRoot "lib\Stackit-CleanupHook.ps1"

            $AuthCmd = "$PSExe -NoProfile -ExecutionPolicy Bypass -File `"$AuthHookPath`""
            $CleanupCmd = "$PSExe -NoProfile -ExecutionPolicy Bypass -File `"$CleanupHookPath`""

            $CertbotArgs = @(
                "certonly",
                "--manual",
                "--manual-auth-hook", $AuthCmd,
                "--manual-cleanup-hook", $CleanupCmd,
                "--preferred-challenges", "dns",
                "--server", $Config.AcmeServer,
                "--agree-tos",
                "-d", $cert.domain,
                "--non-interactive",
                "--force-renewal",
                "--disable-hook-validation"
            )
            & certbot $CertbotArgs

        } else {
            Write-Output "  -> [INFO] Mode: STACKIT DNS Plugin (Direct Zone Update)"
            # Execute Certbot using the official STACKIT DNS plugin
            & certbot certonly --authenticator dns-stackit `
                --dns-stackit-project-id $Config.ProjectId `
                --dns-stackit-service-account $Config.DNS_SAKeyPath `
                --dns-stackit-propagation-seconds 120 `
                --server $Config.AcmeServer `
                --agree-tos -d $cert.domain --non-interactive --force-renewal
        }
        $certbotSuccess = ($LASTEXITCODE -eq 0)

        # --- END OF CERTBOT LOG BOUNDARY ---
        Write-Output "  ^==========================================================^"
        Write-Output ""

        if (-not $certbotSuccess) {
            Write-Error "  [FAIL] Certbot process failed for $($cert.domain)."
            $WorkflowHasErrors = $true
            continue
        }
    } else {
        # SkipCertbot mode: Assume files were generated out-of-band and just deploy them
        Write-Output "  -> [INFO] SkipCertbot enabled. Checking for existing local files..."
        $certbotSuccess = (Test-Path $fullchainPath) -and (Test-Path $privkeyPath)
        if (-not $certbotSuccess) {
            Write-Error "  [FAIL] Local certificate files not found for $($cert.domain)!"
            $WorkflowHasErrors = $true
            continue
        }
    }

    Write-Output "  [+] Certificate generated successfully. Local files are ready."

    # Generate a unique name for the new certificate in STACKIT Certificate Manager
    $safeDomain = $cert.domain -replace '\.', '-'
    $newName = "auto-$($safeDomain)-$(Get-Date -Format 'yyyyMMdd-HHmm')"

    try {
        # Reactivate ALB scope auth (in case Certbot/Hooks altered the active CLI session)
        Write-Output "  -> [Action] Ensuring STACKIT CLI Auth is active before upload..."
        & stackit auth activate-service-account --service-account-key-path $Config.ALB_SAKeyPath

        Write-Output "  -> [Action] Uploading new certificate '$newName' to STACKIT Certificate Manager in project '$($Config.ProjectId)'"
        $newCert = New-StackitCertificate -ProjectId $Config.ProjectId -RegionId $Config.RegionId -CertName $newName -FullchainPath $fullchainPath -PrivkeyPath $privkeyPath -CertBaseUrl $Config.CertBaseUrl
        Write-Output "  [SUCCESS] Certificate successfully uploaded!"

        Write-Output "  -> [Action] Patching ALB to use new Certificate ID: $($newCert.id)..."
        $patch = Update-AlbListenerCert -ProjectId $Config.ProjectId -RegionId $Config.RegionId -AlbName $Config.AlbName -OldCertId $cert.certificateId -NewCertId $newCert.id -AlbBaseUrl $Config.AlbBaseUrl
        Write-Output "  [SUCCESS] ALB successfully updated with the new certificate!"
    } catch {
        Write-Error "  [ERROR] STACKIT platform update failed for $($cert.domain): $($_.Exception.Message)"
        $WorkflowHasErrors = $true
    }
}

if ($WorkflowHasErrors) {
    Write-Error "`n=== Workflow Completed with ERRORS ==="
    Write-Error "At least one certificate failed to renew or deploy. Please check the logs above."
    exit 1
} else {
    Write-Output "`n=== Workflow Completed SUCCESSFULLY ==="
    exit 0
}
