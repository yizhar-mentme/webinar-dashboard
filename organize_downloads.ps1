# organize_downloads.ps1  (UTF-8 BOM)
# Organizes Downloads folder by file type into Hebrew-named subfolders

$Downloads = "C:\Users\yizha\Downloads"

# Extension -> Hebrew folder name
$ExtMap = @{}
foreach ($e in @("pdf","docx","doc","txt","pages","rtf"))         { $ExtMap[$e] = [char]0x05DE + [char]0x05E1 + [char]0x05DE + [char]0x05DB + [char]0x05D9 + [char]0x05DD }  # מסמכים
foreach ($e in @("xlsx","xls","csv"))                              { $ExtMap[$e] = [char]0x05D2 + [char]0x05D9 + [char]0x05DC + [char]0x05D9 + [char]0x05D5 + [char]0x05E0 + [char]0x05D5 + [char]0x05EA }  # גיליונות
foreach ($e in @("png","jpg","jpeg","svg","psd","webp","gif","bmp","tiff")) { $ExtMap[$e] = [char]0x05EA + [char]0x05DE + [char]0x05D5 + [char]0x05E0 + [char]0x05D5 + [char]0x05EA }  # תמונות
foreach ($e in @("pptx","ppt"))                                    { $ExtMap[$e] = [char]0x05DE + [char]0x05E6 + [char]0x05D2 + [char]0x05D5 + [char]0x05EA }  # מצגות
foreach ($e in @("mp4","webm","m4a","srt","mov","avi"))            { $ExtMap[$e] = "Video" }
foreach ($e in @("html","htm","css","js","winmd"))                 { $ExtMap[$e] = "Web" }
foreach ($e in @("ics"))                                           { $ExtMap[$e] = "Calendar" }

$FolderDups  = [char]0x05DB + [char]0x05E4 + [char]0x05D9 + [char]0x05DC + [char]0x05D5 + [char]0x05D9 + [char]0x05D5 + [char]0x05EA  # כפילויות
$FolderMisc  = "Misc"
$TrashExt    = @("exe","msix")
$DupPattern  = [regex]'^(.+?) \(\d+\)$'

function Get-SafeDest([string]$Dir, [string]$Name) {
    $p = Join-Path $Dir $Name
    if (-not (Test-Path $p)) { return $p }
    $stem = [IO.Path]::GetFileNameWithoutExtension($Name)
    $suf  = [IO.Path]::GetExtension($Name)
    $i = 1
    do { $p = Join-Path $Dir "${stem}_moved${i}${suf}"; $i++ } while (Test-Path $p)
    return $p
}

function MoveFile([IO.FileInfo]$f, [string]$Dir) {
    if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir | Out-Null }
    $dest = Get-SafeDest $Dir $f.Name
    Move-Item -LiteralPath $f.FullName -Destination $dest
    Write-Host ("  -> " + $f.Name + "  =>  " + (Split-Path $Dir -Leaf))
}

function TrashFile([IO.FileInfo]$f) {
    $sh  = New-Object -ComObject Shell.Application
    $fld = $sh.Namespace($f.DirectoryName)
    $itm = $fld.ParseName($f.Name)
    $itm.InvokeVerb("delete")
    Write-Host ("  [TRASH] " + $f.Name)
}

# ── Main ──────────────────────────────────────────────────────────────────────
$Files = Get-ChildItem -LiteralPath $Downloads -File
Write-Host ("Found " + $Files.Count + " files in Downloads root")
Write-Host ("=" * 60)

$cnt = @{ ok=0; dup=0; trash=0; err=0 }

foreach ($f in ($Files | Sort-Object Name)) {
    $ext  = $f.Extension.TrimStart(".").ToLower()
    $stem = $f.BaseName

    # 1. Executables -> Recycle Bin
    if ($TrashExt -contains $ext) {
        try   { TrashFile $f; $cnt.trash++ }
        catch { Write-Host ("  ERROR: " + $f.Name + " - " + $_); $cnt.err++ }
        continue
    }

    # 2. Duplicates: "name (N).ext"
    if ($DupPattern.IsMatch($stem)) {
        try   { MoveFile $f (Join-Path $Downloads $FolderDups); $cnt.dup++ }
        catch { Write-Host ("  ERROR: " + $f.Name + " - " + $_); $cnt.err++ }
        continue
    }

    # 3. Categorise
    $dir = if ($ExtMap.ContainsKey($ext)) { Join-Path $Downloads $ExtMap[$ext] } else { Join-Path $Downloads $FolderMisc }
    try   { MoveFile $f $dir; $cnt.ok++ }
    catch { Write-Host ("  ERROR: " + $f.Name + " - " + $_); $cnt.err++ }
}

Write-Host ""
Write-Host ("=" * 60)
Write-Host "Summary:"
Write-Host ("  Classified : " + $cnt.ok)
Write-Host ("  Duplicates : " + $cnt.dup)
Write-Host ("  Trashed    : " + $cnt.trash)
Write-Host ("  Errors     : " + $cnt.err)
Write-Host ("=" * 60)
Write-Host "Done!"
