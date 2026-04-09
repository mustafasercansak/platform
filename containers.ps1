Clear-Host
# Uzak makineden JSON formatında veri çekip PowerShell objesine çeviriyoruz
$remoteHost = (Import-PowerShellDataFile ./server.psd1).RemoteHost
$containers = ssh $remoteHost "docker ps -a --format '{{json .}}'" | ConvertFrom-Json

# Çıktıyı filtreleyip ekrana bas
if ($containers) {
    Write-Host "🚀 Uzak Makinedeki Konteynerler:" -ForegroundColor Cyan
    $containers | Select-Object @{Name="Konteyner"; Expression={$_.Names}}, 
                                @{Name="Durum"; Expression={$_.Status}}, 
                                @{Name="Imaj"; Expression={$_.Image}} | Format-Table -AutoSize
} else {
    Write-Warning "Uzak makinede çalışan konteyner bulunamadı."
}