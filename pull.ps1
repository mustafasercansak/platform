param(
    [Parameter(Mandatory)]
    [string]$ListFile,
    [string]$OutputDir = ".\images"
)

$craneExe = Join-Path $PSScriptRoot "crane.exe"
if (-not (Test-Path $craneExe)) {
    Write-Error "crane.exe bulunamadı: $craneExe"
    exit 1
}

$images = Get-Content $ListFile | Where-Object { $_.Trim() -ne '' -and $_.Trim() -notmatch '^#' }
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$success = 0; $skip = 0; $fail = 0

foreach ($img in $images) {
    $img = $img.Trim()
    Write-Host "`n🐳 $img" -ForegroundColor Cyan
    $safeName = $img -replace '[^a-zA-Z0-9._-]', '_'
    $tarFile = Join-Path $OutputDir "$safeName.tar"

    # Tar dosyası zaten varsa atla
    if (Test-Path $tarFile) {
        Write-Host "⏭️  Tar dosyası zaten var: $tarFile" -ForegroundColor DarkYellow
        $skip++
        continue
    }

    Write-Host "⬇️  İndiriliyor (sadece tar)..." -ForegroundColor Yellow
    $start = Get-Date
    & $craneExe pull $img $tarFile 2>&1 | Out-Null

    if ($LASTEXITCODE -eq 0 -and (Test-Path $tarFile)) {
        $size = (Get-Item $tarFile).Length
        $sizeMB = [math]::Round($size / 1MB, 2)
        $duration = (Get-Date) - $start
        Write-Host "✅ Başarılı (${sizeMB} MB) - $($duration.ToString('mm\:ss'))" -ForegroundColor Green
        $success++
    }
    else {
        Write-Error "❌ İndirme başarısız: $img"
        if (Test-Path $tarFile) { Remove-Item $tarFile }
        $fail++
    }
}

Write-Host "`n📊 Tamamlandı: $success indirildi, $skip atlandı, $fail başarısız." -ForegroundColor White
exit ($fail -gt 0 ? 1 : 0)