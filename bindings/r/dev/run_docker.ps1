# Run streamfind Docker container with local drive mounts
# Mounts your Windows drives (C:\, D:\, etc.) into /host/
# so you can access your files from within the container.

param(
    [string]$Image = "streamfind",
    [string]$Password = "streamfind",
    [int[]]$Ports = @(3838, 8080, 22),
    [switch]$Interactive
)

# ── Drive mounts ────────────────────────────────────────────────
$vols = @()
Get-CimInstance -ClassName Win32_LogicalDisk |
    Where-Object { $_.DriveType -eq 3 -and $_.FileSystem -eq "NTFS" } |
    ForEach-Object { $vols += "--volume $($_.DeviceID)\:/host/$($_.DeviceID.TrimEnd(':'))" }
if ($vols.Count -eq 0) { $vols += "--volume C:\:/host/c" }

# ── Port mappings ───────────────────────────────────────────────
$portFlags = @()
$Ports | ForEach-Object { $portFlags += "-p $($_):$($_)" }

# ── Run ─────────────────────────────────────────────────────────
Write-Host "Starting streamfind container ..."
Write-Host "  Shiny:       http://localhost:3838"
Write-Host "  Code Server: http://localhost:8080 (password: $Password)"
Write-Host "  SSH:         ssh streamfind@localhost -p 22 (password: $Password)"
Write-Host ""

# Remove old container if it exists
docker rm -f streamfind 2>$null

$runFlag = if ($Interactive) { "-it --rm" } else { "-d" }

# Build the full command string and run via cmd to avoid PowerShell splatting issues
$cmd = @"
docker run $runFlag --name streamfind $($portFlags -join ' ') $($vols -join ' ') -e SSH_PASSWORD=$Password -e CS_PASSWORD=$Password $Image
"@
cmd /c $cmd
