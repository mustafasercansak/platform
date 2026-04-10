param(
    [string]$ImagesDir    = ".\images",
    [string]$RemoteTarget = "vys@192.170.6.11",
    [string]$RemoteDir    = "/opt/images"
)

$scp = Get-Command scp.exe -ErrorAction Stop | Select-Object -ExpandProperty Source
$ssh = Get-Command ssh.exe -ErrorAction Stop | Select-Object -ExpandProperty Source

# Uzak makinada hedef dizini oluştur
Write-Host "`n📁 Uzak dizin hazırlanıyor: $RemoteDir" -ForegroundColor Cyan
& $ssh $RemoteTarget "sudo mkdir -p $RemoteDir && sudo chown `$(whoami):`$(whoami) $RemoteDir"

$tars = Get-ChildItem -Path $ImagesDir -Filter "*.tar" -ErrorAction SilentlyContinue
if (-not $tars) {
    Write-Warning "Hiç .tar dosyası bulunamadı: $ImagesDir`nÖnce pull.ps1'i çalıştırın: .\pull.ps1 .\images.txt"
    exit 1
}

$success = 0; $fail = 0

foreach ($tar in $tars) {
    Write-Host "`n🐳 $($tar.Name)" -ForegroundColor Cyan

    # Kopyala
    Write-Host "  ⬆️  Kopyalanıyor..." -ForegroundColor Yellow
    & $scp $tar.FullName "${RemoteTarget}:${RemoteDir}/$($tar.Name)"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "  ❌ SCP başarısız: $($tar.Name)"
        $fail++
        continue
    }

    # Yükle
    Write-Host "  📦 docker load..." -ForegroundColor Yellow
    & $ssh $RemoteTarget "sudo docker load -i ${RemoteDir}/$($tar.Name)"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "  ❌ docker load başarısız: $($tar.Name)"
        $fail++
        continue
    }

    Write-Host "  ✅ Tamamlandı" -ForegroundColor Green
    $success++
}

Write-Host "`n📊 Sonuç: $success başarılı, $fail başarısız." -ForegroundColor White
exit ($fail -gt 0 ? 1 : 0)
