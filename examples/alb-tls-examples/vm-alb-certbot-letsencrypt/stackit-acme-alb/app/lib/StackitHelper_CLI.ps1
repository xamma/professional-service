<#
.SYNOPSIS
    STACKIT API Interaction Helpers

.DESCRIPTION
    Provides functions to interact with the STACKIT Certificate Manager and the
    Application Load Balancer API to deploy newly generated certificates.
#>

function New-StackitCertificate {
    <#
    .SYNOPSIS
        Uploads a local PEM certificate and private key to STACKIT Certificate Manager.
    #>
    param ($ProjectId, $RegionId, $CertName, $FullchainPath, $PrivkeyPath, $CertBaseUrl)

    # Read the PEM files and normalize line endings (CRLF to LF) for API compatibility
    $cert = (Get-Content -Raw $FullchainPath) -replace "`r`n", "`n"
    $key  = (Get-Content -Raw $PrivkeyPath) -replace "`r`n", "`n"

    # Construct the JSON payload expected by STACKIT
    $body = @{
        name       = $CertName
        publicKey  = $cert.Trim()
        privateKey = $key.Trim()
    } | ConvertTo-Json

    $url = "$CertBaseUrl/projects/$ProjectId/regions/$RegionId/certificates"

    # Store payload in a temporary file to safely pass it to the curl wrapper
    $tempFile = New-TemporaryFile

    try {
        # Ensure UTF8 encoding without Byte Order Mark (BOM) to prevent parsing errors
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($tempFile.FullName, $body, $utf8NoBom)

        $response = stackit curl -X POST $url --data "@$($tempFile.FullName)"

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to upload new certificate '$CertName' to STACKIT Certificate Manager. API Output: $response"
        }

        return $response | ConvertFrom-Json
    }
    catch {
        Write-Error "[ERROR] New-StackitCertificate: $($_.Exception.Message)"
        throw
    }
    finally {
        if (Test-Path $tempFile.FullName) {
            Remove-Item -Path $tempFile.FullName -Force
        }
    }
}

function Update-AlbListenerCert {
    <#
    .SYNOPSIS
        Patches an existing Application Load Balancer to use a newly uploaded certificate ID.
    #>
    param ($ProjectId, $RegionId, $AlbName, $OldCertId, $NewCertId, $AlbBaseUrl)

    $url = "$AlbBaseUrl/projects/$ProjectId/regions/$RegionId/load-balancers/$AlbName"

    # 1. Retrieve the complete, current state of the ALB
    $alb = stackit curl -X GET $url | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve current configuration for ALB '$AlbName' from STACKIT API."
    }

    # 2. Iterate through listeners and replace the old Certificate ID with the new one
    $changed = $false
    foreach ($l in $alb.listeners) {
        if ($l.protocol -eq "PROTOCOL_HTTPS" -and $l.https.certificateConfig) {
            $ids = $l.https.certificateConfig.certificateIds
            for ($i=0; $i -lt $ids.Count; $i++) {
                if ($ids[$i] -eq $OldCertId) {
                    $ids[$i] = $NewCertId
                    $changed = $true
                }
            }
        }
    }

    # 3. If modifications were made, we must push the entire state back via PUT
    if ($changed) {

        # CRITICAL: The GET request returns read-only state variables.
        # Sending these back in a PUT request will cause the STACKIT API to reject the payload.
        # We must explicitly strip them from the object.
        $alb.PSObject.Properties.Remove("status")
        $alb.PSObject.Properties.Remove("loadBalancerSecurityGroup")
        $alb.PSObject.Properties.Remove("targetSecurityGroup")

        if ($alb.options -and $alb.options.ephemeralAddress -eq $true) {
            $alb.PSObject.Properties.Remove("externalAddress")
        }

        # Convert back to JSON, ensuring nested arrays (like listeners) are not truncated
        $body = $alb | ConvertTo-Json -Depth 20
        $tempFile = New-TemporaryFile

        try {
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            [System.IO.File]::WriteAllText($tempFile.FullName, $body, $utf8NoBom)

            $response = stackit curl -X PUT $url --data "@$($tempFile.FullName)"

            if ($LASTEXITCODE -ne 0) {
                throw "Failed to update listener configuration for ALB '$AlbName' with new Certificate ID '$NewCertId'. API Output: $response"
            }
            return $true
        }
        catch {
            Write-Error "[ERROR] Update-AlbListenerCert: $($_.Exception.Message)"
            throw
        }
        finally {
            if (Test-Path $tempFile.FullName) {
                Remove-Item -Path $tempFile.FullName -Force
            }
        }
    }

    return $false
}
