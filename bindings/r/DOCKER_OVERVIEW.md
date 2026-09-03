# Docker Overview

This repository contains a Docker image for `streamfind` with these main services:

- Shiny app
- code-server (browser VS Code)
- SSH access

Main repository:

- https://github.com/ricardo-cunha/streamfind

## Build

Build the image from the R package root:

```powershell
docker build -t streamfind bindings/r
```

## Services

After starting the container, these endpoints are available by default:

- Shiny: `http://localhost:3838`
- code-server: `http://localhost:8080`
- SSH: `ssh streamfind@localhost -p 22`

Default passwords:

- code-server: `streamfind`
- SSH: `streamfind`

You can override them with environment variables:

- `CS_PASSWORD`
- `SSH_PASSWORD`

## Run

Minimal detached run:

```powershell
docker run -d ^
  --name streamfind ^
  -p 3838:3838 ^
  -p 8080:8080 ^
  -p 22:22 ^
  -e CS_PASSWORD=streamfind ^
  -e SSH_PASSWORD=streamfind ^
  streamfind
```

Interactive run:

```powershell
docker run -it --rm ^
  --name streamfind ^
  -p 3838:3838 ^
  -p 8080:8080 ^
  -p 22:22 ^
  -e CS_PASSWORD=streamfind ^
  -e SSH_PASSWORD=streamfind ^
  streamfind
```

## Volumes

The container expects host files under `/host`.

### Mount one folder

Example: mount the current repository into `/host/work`:

```powershell
docker run -d ^
  --name streamfind ^
  -p 3838:3838 ^
  -p 8080:8080 ^
  -p 22:22 ^
  -v "${PWD}:/host/work" ^
  streamfind
```

### Mount one drive

Example: mount `D:\` into `/host/D`:

```powershell
docker run -d ^
  --name streamfind ^
  -p 3838:3838 ^
  -p 8080:8080 ^
  -p 22:22 ^
  -v "D:\:/host/D" ^
  streamfind
```

### Mount multiple drives

Example: mount `C:\` and `D:\`:

```powershell
docker run -d ^
  --name streamfind ^
  -p 3838:3838 ^
  -p 8080:8080 ^
  -p 22:22 ^
  -v "C:\:/host/C" ^
  -v "D:\:/host/D" ^
  streamfind
```

### Use the helper script

This package includes a PowerShell helper that mounts fixed NTFS drives automatically:

```powershell
.\bindings\r\dev\run_docker.ps1
```

Interactive mode:

```powershell
.\bindings\r\dev\run_docker.ps1 -Interactive
```

Custom password:

```powershell
.\bindings\r\dev\run_docker.ps1 -Password mypass
```

## Working In code-server

Once code-server is open:

1. Open a folder under `/host/...`
2. Use the integrated terminal for R or shell work
3. Use the preinstalled R extension for R editing support

## Working In Shiny

The Shiny app starts automatically and binds to `0.0.0.0:3838`.

It uses the installed `streamfind` package and OpenBabel data from:

```text
/usr/local/lib/R/site-library/streamfind/extdata/openbabel/data
```

## SSH

Connect with:

```powershell
ssh streamfind@localhost -p 22
```

## Stop / Remove

Stop:

```powershell
docker stop streamfind
```

Remove:

```powershell
docker rm -f streamfind
```

## Notes

- The image is intended to run the packaged app and development tooling, not to mirror the host R installation.
