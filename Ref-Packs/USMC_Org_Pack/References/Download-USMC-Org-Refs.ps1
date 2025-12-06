param([string]$DestDir = 'docs')
New-Item -ItemType Directory -Force -Path $DestDir | Out-Null
Invoke-WebRequest -UseBasicParsing -Uri "https://www.marines.mil/Portals/1/Publications/MCRP%201-10.1.pdf" -OutFile (Join-Path $DestDir "MCRP_1-10.1.pdf")
Invoke-WebRequest -UseBasicParsing -Uri "https://www.marines.mil/Portals/1/Publications/MCWP%205-10.pdf" -OutFile (Join-Path $DestDir "MCWP_5-10.pdf")
