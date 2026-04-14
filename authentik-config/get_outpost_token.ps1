# Terraform external data source JSON veriyi STDIN üzerinden gönderir
$json = $input | Out-String | ConvertFrom-Json

$authentik_url = $json.authentik_url
$authentik_token = $json.authentik_token
$outpost_id = $json.outpost_id

# Debug için gelen verileri loglayalım
$logFile = "c:\Users\sercan.sak\projects\platform\authentik-config\debug_token.log"
"--- NEW RUN (TWO-STEP) ---" | Out-File $logFile -Append

if ([string]::IsNullOrWhiteSpace($authentik_url)) {
    Write-Error "Authentik URL is empty"
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $authentik_token"
    "Accept"        = "application/json"
}

try {
    # 1. ADIM: Outpost bilgilerinden token_identifier'ı al
    $outpostUri = "$authentik_url/api/v3/outposts/instances/$outpost_id/"
    $outpostRes = Invoke-RestMethod -Uri $outpostUri -Headers $headers -Method Get
    $tokenIdentifier = $outpostRes.token_identifier
    "Found Token Identifier: $tokenIdentifier" | Out-File $logFile -Append

    if ([string]::IsNullOrWhiteSpace($tokenIdentifier)) {
        Write-Error "Token identifier not found for outpost $outpost_id"
        exit 1
    }

    # 2. ADIM: Token identifier ile asıl KEY (secret) değerini çek
    $tokenUri = "$authentik_url/api/v3/core/tokens/$tokenIdentifier/"
    $tokenRes = Invoke-RestMethod -Uri $tokenUri -Headers $headers -Method Get
    $secretKey = $tokenRes.key
    "Successfully retrieved token secret key." | Out-File $logFile -Append

    if ([string]::IsNullOrWhiteSpace($secretKey)) {
        Write-Error "Secret key is null for token $tokenIdentifier"
        exit 1
    }

    $output = @{
        token = $secretKey
    }
    
    $output | ConvertTo-Json
} catch {
    $error_msg = $_.Exception.Message
    "ERROR: $error_msg" | Out-File $logFile -Append
    Write-Error "Failed to fetch outpost token: $error_msg"
    exit 1
}
