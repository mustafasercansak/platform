# remote-docker-nuke.ps1
# Uzak makinedeki tüm Docker kaynaklarını temizler
# Kullanım: .\remote-docker-nuke.ps1 -Host "sa@192.168.137.11"

param(
    [string]$ConfigFile = "./server.psd1"
)

$config     = Import-PowerShellDataFile $ConfigFile
$RemoteHost = $config.RemoteHost
$KeepImages = $config.KeepImages
$DryRun     = $config.DryRun

$ErrorActionPreference = "Stop"

function Invoke-Remote {
    param([string]$Command)
    ssh $RemoteHost $Command
}

function Write-Section {
    param([string]$Title)
    Write-Host "`n━━━ $Title ━━━" -ForegroundColor Cyan
}

# ─── Bağlantı Testi ───────────────────────────────────────────────────────────
Write-Host "Bağlantı test ediliyor: $RemoteHost" -ForegroundColor Yellow
try {
    Invoke-Remote "docker info --format '{{.ServerVersion}}'" | Out-Null
    Write-Host "✓ Bağlantı OK" -ForegroundColor Green
} catch {
    Write-Host "✗ SSH bağlantısı kurulamadı: $_" -ForegroundColor Red
    exit 1
}

# ─── Mevcut Durumu Listele ────────────────────────────────────────────────────
Write-Section "MEVCUT DURUM"

Write-Host "`n[Container'lar]" -ForegroundColor White
Invoke-Remote "docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'"

Write-Host "`n[Volume'lar]" -ForegroundColor White
Invoke-Remote "docker volume ls"

Write-Host "`n[Network'ler]" -ForegroundColor White
Invoke-Remote "docker network ls --filter 'type=custom'"

if (-not $KeepImages) {
    Write-Host "`n[Image'lar]" -ForegroundColor White
    Invoke-Remote "docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}'"
}

# ─── Onay ────────────────────────────────────────────────────────────────────
if (-not $Force -and -not $DryRun) {
    Write-Host "`n" -NoNewline
    Write-Host "⚠️  UYARI: " -ForegroundColor Red -NoNewline
    Write-Host "$RemoteHost üzerindeki TÜM Docker kaynakları silinecek!" -ForegroundColor Yellow
    $confirm = Read-Host "Devam etmek için 'EVET' yazın"
    if ($confirm -ne "EVET") {
        Write-Host "İptal edildi." -ForegroundColor Gray
        exit 0
    }
}

if ($DryRun) {
    Write-Host "`n[DRY RUN] Hiçbir şey silinmedi." -ForegroundColor Magenta
    exit 0
}

# ─── Temizlik ─────────────────────────────────────────────────────────────────
Write-Section "TEMİZLİK BAŞLIYOR"

# 1. Çalışan container'ları durdur
Write-Host "`n[1/4] Container'lar durduruluyor..." -ForegroundColor Yellow
$runningContainers = Invoke-Remote "docker ps -q"
if ($runningContainers) {
    Invoke-Remote "docker stop `$(docker ps -q) 2>/dev/null || true"
    Write-Host "✓ Çalışan container'lar durduruldu" -ForegroundColor Green
} else {
    Write-Host "  Çalışan container yok" -ForegroundColor Gray
}

# 2. Tüm container'ları sil
Write-Host "`n[2/4] Container'lar siliniyor..." -ForegroundColor Yellow
$result = Invoke-Remote "docker rm -f `$(docker ps -aq) 2>/dev/null; echo 'done'"
Write-Host "✓ Container'lar silindi" -ForegroundColor Green

# 3. Volume'ları sil
Write-Host "`n[3/4] Volume'lar siliniyor..." -ForegroundColor Yellow
Invoke-Remote "docker volume rm `$(docker volume ls -q) 2>/dev/null; echo 'done'" | Out-Null
Write-Host "✓ Volume'lar silindi" -ForegroundColor Green

# 4. Custom network'leri sil (bridge/host/none dokunulmaz)
Write-Host "`n[4/4] Custom network'ler siliniyor..." -ForegroundColor Yellow
Invoke-Remote "docker network rm `$(docker network ls --filter type=custom -q) 2>/dev/null; echo 'done'" | Out-Null
Write-Host "✓ Network'ler silindi" -ForegroundColor Green

# 5. Image'lar (opsiyonel)
if (-not $KeepImages) {
    Write-Host "`n[+] Image'lar siliniyor..." -ForegroundColor Yellow
    Invoke-Remote "docker rmi -f `$(docker images -aq) 2>/dev/null; echo 'done'" | Out-Null
    Write-Host "✓ Image'lar silindi" -ForegroundColor Green
}

# 6. Build cache temizle
Write-Host "`n[+] Build cache temizleniyor..." -ForegroundColor Yellow
Invoke-Remote "docker builder prune -af 2>/dev/null; echo 'done'" | Out-Null
Write-Host "✓ Build cache temizlendi" -ForegroundColor Green

# ─── Final Durum ──────────────────────────────────────────────────────────────
Write-Section "SONUÇ"

Write-Host "`n[Container'lar]" -ForegroundColor White
Invoke-Remote "docker ps -a"

Write-Host "`n[Volume'lar]" -ForegroundColor White
Invoke-Remote "docker volume ls"

Write-Host "`n[Network'ler]" -ForegroundColor White
Invoke-Remote "docker network ls"

if (-not $KeepImages) {
    Write-Host "`n[Image'lar]" -ForegroundColor White
    Invoke-Remote "docker images"
}

Write-Host "`n✓ Temizlik tamamlandı." -ForegroundColor Green