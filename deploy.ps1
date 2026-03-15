param(
    [string]$WorkDir = $PSScriptRoot,
    [string]$SshHost = "192.168.137.11",
    [string]$SshUser = "sa",
    [string]$SshKey = "~/.ssh/id_rsa",
    [ValidateSet("install", "uninstall", "reinstall", "init", "plan", "apply", "destroy", "nuke", "reset", "dashboard", "stop-dashboard", "vault-init")]
    [string]$Action = "plan"
)

Clear-Host
$ErrorActionPreference = "Stop"

# ─── Yardımcı Fonksiyonlar ───────────────────────────────────────────────────

function Invoke-Terraform {
    param([string]$Cmd)
    Write-Host "`n→ terraform $Cmd" -ForegroundColor Cyan
    Push-Location $WorkDir
    try {
        $parts = $Cmd -split ' '
        & terraform @parts
        if ($LASTEXITCODE -ne 0) {
            Write-Host "✗ Komut başarısız (exit $LASTEXITCODE)" -ForegroundColor Red
            exit $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-Remote {
    param([string]$Cmd, [string]$Desc = "")
    if ($Desc) { Write-Host "`n→ $Desc" -ForegroundColor Cyan }
    else { Write-Host "`n→ $Cmd" -ForegroundColor Cyan }
    ssh -i $SshKey "$SshUser@$SshHost" $Cmd
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Komut başarısız (exit $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

function Sync-Kubeconfig {
    Write-Host "`n→ Kubeconfig uzak makineden alınıyor..." -ForegroundColor Cyan
    $kubeDir = "$HOME\.kube"
    if (-not (Test-Path $kubeDir)) { New-Item -ItemType Directory -Path $kubeDir | Out-Null }
    ssh -i $SshKey "$SshUser@$SshHost" "microk8s config" | Out-File -Encoding utf8 "$kubeDir\config"
    Write-Host "✓ Kubeconfig güncellendi." -ForegroundColor Green
}

function Wait-MicroK8s {
    Write-Host "`n→ MicroK8s hazır olana kadar bekleniyor..." -ForegroundColor Cyan
    Invoke-Remote "sudo microk8s status --wait-ready --timeout 120" "MicroK8s status bekle"
    Write-Host "✓ MicroK8s hazır." -ForegroundColor Green
}

function Install-MicroK8s {
    Write-Host "`n→ MicroK8s kuruluyor..." -ForegroundColor Cyan

    # MicroK8s kur
    Invoke-Remote "sudo snap install microk8s --classic --channel=1.32/stable" "MicroK8s snap install"
    Invoke-Remote "sudo usermod -aG microk8s $SshUser" "Kullanıcı gruba ekleniyor"
    Invoke-Remote "sudo microk8s status --wait-ready --timeout 120" "MicroK8s başlaması bekleniyor"

    # Addon'lar
    $addons = @(
        "dns",
        "helm3",
        "cert-manager",
        "dashboard",
        "ingress",
        "metrics-server",
        "hostpath-storage",
        "registry",
        "observability"
    )

    foreach ($addon in $addons) {
        Invoke-Remote "sudo microk8s enable $addon" "Addon etkinleştiriliyor: $addon"
        Start-Sleep -Seconds 5
    }

    # Addon'ların hazır olmasını bekle
    Invoke-Remote "sudo microk8s status --wait-ready --timeout 180" "Addon'lar hazır olana kadar bekle"

    # kubectl alias
    Invoke-Remote "echo 'alias kubectl=""sudo microk8s kubectl""' >> ~/.bashrc" "kubectl alias ekleniyor"

    Write-Host "✓ MicroK8s kurulumu tamamlandı." -ForegroundColor Green
}

function Uninstall-MicroK8s {
    Write-Host "`n→ MicroK8s kaldırılıyor..." -ForegroundColor Cyan

    Write-Host "`n→ Terraform kaynakları siliniyor..." -ForegroundColor Cyan
    try {
        Invoke-Terraform "init -input=false"
        Invoke-Terraform "destroy -auto-approve -refresh=false"
    }
    catch {
        Write-Host "⚠ Terraform destroy başarısız, devam ediliyor..." -ForegroundColor Yellow
    }

    Clear-TerraformState

    Invoke-Remote "sudo microk8s kubectl get namespaces --no-headers -o custom-columns=':metadata.name' 2>/dev/null | grep -v -E '^(kube-system|kube-public|kube-node-lease|default)$' | xargs -r sudo microk8s kubectl delete namespace --force --grace-period=0 2>/dev/null || true" "Kalan namespace'ler siliniyor"

    Start-Sleep -Seconds 5

    Invoke-Remote "sudo microk8s stop" "MicroK8s durduruluyor"
    Start-Sleep -Seconds 5
    Invoke-Remote "sudo snap remove microk8s --purge" "MicroK8s snap kaldırılıyor"
    Invoke-Remote "sudo rm -rf /var/snap/microk8s /root/.kube ~/.kube /etc/microk8s" "Kalan dosyalar temizleniyor"

    $kubeConfig = "$HOME\.kube\config"
    if (Test-Path $kubeConfig) {
        Remove-Item $kubeConfig -Force
        Write-Host "✓ Local kubeconfig temizlendi." -ForegroundColor Green
    }

    Write-Host "✓ MicroK8s tamamen kaldırıldı." -ForegroundColor Green
}

function Clear-TerraformState {
    Write-Host "`n→ Terraform state ve cache temizleniyor..." -ForegroundColor Cyan
    Remove-Item -Recurse -Force "$WorkDir\.terraform",
    "$WorkDir\.terraform.lock.hcl",
    "$WorkDir\terraform.tfstate",
    "$WorkDir\terraform.tfstate.backup" -ErrorAction SilentlyContinue
    Write-Host "✓ Temizlendi." -ForegroundColor Green
}

# ─── Header ─────────────────────────────────────────────────────────────────

Write-Host "=== Platform Deploy ===" -ForegroundColor Yellow
Write-Host "Dir    : $WorkDir"
Write-Host "Host   : $SshHost"
Write-Host "Action : $Action`n"

# ─── Actions ─────────────────────────────────────────────────────────────────

switch ($Action) {

    "install" {
        $confirm = Read-Host "MicroK8s kurulacak. Devam? (yes/no)"
        if ($confirm -ne "yes") { Write-Host "İptal."; exit 0 }
        Install-MicroK8s
        Sync-Kubeconfig
        Write-Host "`n✓ Kurulum tamamlandı. 'apply' ile devam edebilirsin." -ForegroundColor Green
    }

    "uninstall" {
        $confirm = Read-Host "MicroK8s + tüm veriler + Terraform state silinecek. Devam? (yes/no)"
        if ($confirm -ne "yes") { Write-Host "İptal."; exit 0 }
        Uninstall-MicroK8s
        Write-Host "`n✓ Her şey silindi. Yeniden kurmak için: .\deploy.ps1 -Action install" -ForegroundColor Green
    }

    "reinstall" {
        $confirm = Read-Host "Her şey silinip yeniden kurulacak. Devam? (yes/no)"
        if ($confirm -ne "yes") { Write-Host "İptal."; exit 0 }
        # Terraform destroy
        try {
            Invoke-Terraform "destroy -auto-approve"
        }
        catch {
            Write-Host "⚠ Terraform destroy başarısız, devam ediliyor..." -ForegroundColor Yellow
        }
        Clear-TerraformState
        Uninstall-MicroK8s
        Start-Sleep -Seconds 10
        Install-MicroK8s
        Sync-Kubeconfig
        Invoke-Terraform "init -input=false"
        Invoke-Terraform "apply -auto-approve -target=module.authentik -target=random_password.all"
        Write-Host "`n→ Authentik hazır olana kadar bekleniyor (90s)..." -ForegroundColor Cyan
        Start-Sleep -Seconds 90
        Invoke-Terraform "apply -auto-approve"
        Write-Host "`n→ Şifreler:" -ForegroundColor Yellow
        Invoke-Terraform "output -json passwords"
        Write-Host "`n→ Dashboard token:" -ForegroundColor Yellow
        Invoke-Terraform "output -raw dashboard_token"
    }

    "init" {
        Sync-Kubeconfig
        Invoke-Terraform "init"
    }

    "plan" {
        Sync-Kubeconfig
        Invoke-Terraform "init -input=false"
        Invoke-Terraform "plan"
    }

    "apply" {
        Sync-Kubeconfig
        Invoke-Terraform "init -input=false"
        Invoke-Terraform "apply -auto-approve -target=module.authentik -target=random_password.all"
        Write-Host "`n→ Authentik hazır olana kadar bekleniyor (90s)..." -ForegroundColor Cyan
        Start-Sleep -Seconds 90
        # Vault token'ı sor
        $vaultToken = Read-Host "Vault Root Token (boş bırakırsan atlanır)"
        if ($vaultToken) { $env:VAULT_TOKEN = $vaultToken }
        Invoke-Terraform "apply -auto-approve"
        if ($vaultToken) { $env:VAULT_TOKEN = $null }
        Write-Host "`n→ Şifreler:" -ForegroundColor Yellow
        Invoke-Terraform "output -json passwords"
        Write-Host "`n→ Dashboard token:" -ForegroundColor Yellow
        & terraform -chdir="$WorkDir" output -raw dashboard_token
    }

    "destroy" {
        $confirm = Read-Host "Terraform resource'ları silinecek. Devam? (yes/no)"
        if ($confirm -ne "yes") { Write-Host "İptal."; exit 0 }
        Sync-Kubeconfig
        Invoke-Terraform "destroy -auto-approve -refresh=false"
    }

    "nuke" {
        $confirm = Read-Host "Destroy + temiz apply yapılacak. Devam? (yes/no)"
        if ($confirm -ne "yes") { Write-Host "İptal."; exit 0 }
        Sync-Kubeconfig
        Invoke-Terraform "destroy -auto-approve -refresh=false"
        Clear-TerraformState
        Invoke-Terraform "init -input=false"
        Invoke-Terraform "apply -auto-approve -target=module.authentik -target=random_password.all"
        Write-Host "`n→ Authentik hazır olana kadar bekleniyor (90s)..." -ForegroundColor Cyan
        Start-Sleep -Seconds 90
        Invoke-Terraform "apply -auto-approve"
        Write-Host "`n→ Şifreler:" -ForegroundColor Yellow
        Invoke-Terraform "output -json passwords"
        Write-Host "`n→ Dashboard token:" -ForegroundColor Yellow
        Invoke-Terraform "output -raw dashboard_token"
    }

    "reset" {
        $confirm = Read-Host "Terraform destroy + K8s temizliği yapılacak. Devam? (yes/no)"
        if ($confirm -ne "yes") { Write-Host "İptal."; exit 0 }
        Sync-Kubeconfig
        try {
            Invoke-Terraform "destroy -auto-approve -refresh=false"
        }
        catch {
            Write-Host "⚠ Terraform destroy başarısız, K8s temizliğine geçiliyor..." -ForegroundColor Yellow
        }
        # K8s namespace temizliği
        Invoke-Remote @"
sudo microk8s kubectl get namespaces --no-headers -o custom-columns=':metadata.name' | \
grep -v -E '^(kube-system|kube-public|kube-node-lease|default|cert-manager|ingress|observability)$' | \
xargs -r sudo microk8s kubectl delete namespace --force --grace-period=0
"@ "K8s namespace'leri temizleniyor"
        Invoke-Remote "sudo microk8s kubectl get namespaces --no-headers -o custom-columns=':metadata.name' 2>/dev/null | grep -v -E '^(kube-system|kube-public|kube-node-lease|default)$' | xargs -r sudo microk8s kubectl delete namespace --force --grace-period=0 2>/dev/null || true" "Kalan namespace'ler siliniyor"
        Clear-TerraformState
        Write-Host "`n✓ Reset tamamlandı." -ForegroundColor Green
    }

    "dashboard" {
        Sync-Kubeconfig
        Write-Host "`n→ Dashboard token:" -ForegroundColor Yellow
        & terraform -chdir="$WorkDir" output -raw dashboard_token
        Write-Host "`n`n→ Dashboard port-forward başlatılıyor..." -ForegroundColor Cyan
        ssh -i $SshKey "$SshUser@$SshHost" "nohup sudo microk8s kubectl port-forward -n kube-system svc/kubernetes-dashboard 10443:443 --address 0.0.0.0 >/tmp/dashboard-pf.log 2>&1 </dev/null &"
        Start-Sleep -Seconds 3
        $check = ssh -i $SshKey "$SshUser@$SshHost" "ss -tlnp | grep 10443"
        if ($check) {
            Write-Host "✓ Dashboard: https://$SshHost`:10443" -ForegroundColor Green
        }
        else {
            Write-Host "✗ Port-forward başlatılamadı." -ForegroundColor Red
            ssh -i $SshKey "$SshUser@$SshHost" "cat /tmp/dashboard-pf.log"
        }
    }
    
    "stop-dashboard" {
        Write-Host "`n→ Dashboard port-forward kapatılıyor..." -ForegroundColor Cyan
        ssh -i $SshKey "$SshUser@$SshHost" "if [ -f /tmp/dashboard-pf.pid ]; then sudo kill `$(cat /tmp/dashboard-pf.pid) && rm /tmp/dashboard-pf.pid && echo 'Durduruldu.'; else echo 'Zaten kapalı.'; fi"
    }

    "vault-init" {
        Sync-Kubeconfig
        $vaultPod = ssh -i $SshKey "$SshUser@$SshHost" "sudo microk8s kubectl get pods -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}'"

        # Zaten init edilmiş mi kontrol et
        $status = ssh -i $SshKey "$SshUser@$SshHost" "sudo microk8s kubectl exec -n vault $vaultPod -- vault status -format=json 2>/dev/null"
        $statusJson = $status | ConvertFrom-Json

        if ($statusJson.initialized) {
            Write-Host "⚠ Vault zaten init edilmiş. Unseal key gir:" -ForegroundColor Yellow
            $unsealKey = Read-Host "Unseal Key"
            $rootToken = Read-Host "Root Token"
        }
        else {
            $initOutput = ssh -i $SshKey "$SshUser@$SshHost" "sudo microk8s kubectl exec -n vault $vaultPod -- vault operator init -key-shares=1 -key-threshold=1 -format=json"
            $initJson = $initOutput | ConvertFrom-Json
            $unsealKey = $initJson.unseal_keys_b64[0]
            $rootToken = $initJson.root_token
            Write-Host "`n=== Vault Credentials ===" -ForegroundColor Yellow
            Write-Host "Unseal Key : $unsealKey" -ForegroundColor White
            Write-Host "Root Token : $rootToken" -ForegroundColor White
            Write-Host "⚠ Bu bilgileri güvenli bir yere kaydet!" -ForegroundColor Red
        }

        ssh -i $SshKey "$SshUser@$SshHost" "sudo microk8s kubectl exec -n vault $vaultPod -- vault operator unseal $unsealKey"

        Write-Host "`n→ Vault OIDC yapılandırılıyor..." -ForegroundColor Cyan
        $env:VAULT_TOKEN = $rootToken
        Invoke-Terraform "apply -auto-approve"
        $env:VAULT_TOKEN = $null
    }
}

Write-Host "`n✓ Tamamlandı." -ForegroundColor Green