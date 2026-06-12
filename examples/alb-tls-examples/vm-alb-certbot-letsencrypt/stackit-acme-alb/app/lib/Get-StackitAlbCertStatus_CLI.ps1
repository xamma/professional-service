<#
.SYNOPSIS
    Evaluates STACKIT ALB Certificate Expiration

.DESCRIPTION
    This helper script retrieves the current configuration of the STACKIT Application Load Balancer.
    It extracts the IDs of all bound certificates, retrieves their public keys from the Certificate Manager,
    and calculates the exact expiration dates using native X509 .NET classes.
#>
function Get-StackitAlbCertStatus {
    param (
        [Parameter(Mandatory=$true)] [string]$ProjectId,
        [Parameter(Mandatory=$true)] [string]$RegionId,
        [Parameter(Mandatory=$true)] [string]$AlbName,
        [Parameter(Mandatory=$false)] [string[]]$Whitelist = @(),
        [Parameter(Mandatory=$false)] [int]$DaysWarning = 30,
        [Parameter(Mandatory=$false)] [string]$AlbBaseUrl = "https://alb.api.stackit.cloud/v2",
        [Parameter(Mandatory=$false)] [string]$CertBaseUrl = "https://certificates.api.stackit.cloud/v2",
        [Parameter(Mandatory=$false)] [switch]$ForceRenew
    )

    $CertResults = New-Object System.Collections.Generic.List[PSCustomObject]

    try {
        # 1. Fetch current ALB state
        $AlbUrl = "$AlbBaseUrl/projects/$ProjectId/regions/$RegionId/load-balancers/$AlbName"
        $Alb = stackit curl -X GET $AlbUrl | ConvertFrom-Json

        # 2. Iterate through listeners and extract bound certificate IDs
        foreach ($Listener in $Alb.listeners) {
            if ($Listener.protocol -eq "PROTOCOL_HTTPS" -and $Listener.https.certificateConfig.certificateIds) {
                foreach ($HostRule in $Listener.http.hosts) {

                    # Apply whitelist filtering if specified
                    if ($Whitelist.Count -eq 0 -or $Whitelist -contains $HostRule.host) {
                        foreach ($CertId in $Listener.https.certificateConfig.certificateIds) {

                            # Bypass calculation if forced renewal is triggered
                            if ($ForceRenew) {
                                $CertResults.Add([PSCustomObject]@{
                                    domain        = $HostRule.host
                                    certificateId = $CertId
                                    name          = "Forced-Check"
                                    expiryDate    = "FORCED"
                                    daysLeft      = 0
                                    shouldReplace = $true
                                })
                                continue
                            }

                            # 3. Retrieve actual certificate details from STACKIT Certificate Manager
                            $CertUrl = "$CertBaseUrl/projects/$ProjectId/regions/$RegionId/certificates/$CertId"
                            try {
                                $CertJson = stackit curl -X GET $CertUrl | ConvertFrom-Json

                                # Note: The STACKIT API returns the public key inside a JSON string.
                                # We must extract the raw PEM, strip headers, and sanitize it for Base64 conversion.
                                $rawCert = $CertJson.publicKey
                                $firstCertPart = ($rawCert -split "-----END CERTIFICATE-----")[0]
                                $cleanB64 = ($firstCertPart -replace "-----BEGIN CERTIFICATE-----", "") -replace '[^a-zA-Z0-9\+\/=]', ''

                                # Pad Base64 string if necessary to avoid format exceptions
                                while ($cleanB64.Length % 4 -ne 0) { $cleanB64 += "=" }

                                # Load the byte array into a .NET X509 object to reliably read the expiration date (NotAfter)
                                $certBytes = [System.Convert]::FromBase64String($cleanB64)
                                $x509 = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certBytes)

                                $CertResults.Add([PSCustomObject]@{
                                    domain        = $HostRule.host
                                    certificateId = $CertId
                                    name          = $CertJson.name
                                    expiryDate    = $x509.NotAfter.ToString("yyyy-MM-dd")
                                    daysLeft      = ($x509.NotAfter - (Get-Date)).Days
                                    shouldReplace = (($x509.NotAfter - (Get-Date)).Days -lt $DaysWarning)
                                })
                            } catch {
                                $CertResults.Add([PSCustomObject]@{ domain = $HostRule.host; error = "CLI Error processing $CertId" })
                            }
                        }
                    }
                }
            }
        }

        # Return unique certificates (a cert might be bound to multiple listeners)
        return [PSCustomObject]@{
            projectId    = $ProjectId;
            albName      = $AlbName;
            certificates = $CertResults | Select-Object -Unique * }
    } catch {
        throw "ALB Request via STACKIT CLI failed: $($_.Exception.Message)"
    }
}
