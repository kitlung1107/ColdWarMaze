Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path $PSScriptRoot -Parent
$source = [System.Drawing.Image]::FromFile((Join-Path $projectRoot 'assets/icon-source.png'))
function Save-IconPng($size, $relativePath) {
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($source, 0, 0, $size, $size)
    $bitmap.Save((Join-Path $projectRoot $relativePath), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}
Save-IconPng 1024 'assets/icon.png'
Save-IconPng 512 'web/icon-512.png'
Save-IconPng 192 'web/icon-192.png'
Save-IconPng 180 'web/apple-touch-icon.png'
Save-IconPng 32 'web/favicon-32.png'
Save-IconPng 16 'web/favicon-16.png'
# PNG-compressed ICO with both small browser and large desktop entries.
$sizes = @(16,32,48,64,128,256)
$payloads = @()
foreach ($size in $sizes) {
    $bitmap = [System.Drawing.Bitmap]::new($size,$size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($source,0,0,$size,$size)
    $stream = [System.IO.MemoryStream]::new()
    $bitmap.Save($stream,[System.Drawing.Imaging.ImageFormat]::Png)
    $payloads += ,$stream.ToArray()
    $stream.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
}
$file = [System.IO.File]::Create((Join-Path $projectRoot 'assets/icon.ico'))
$writer = [System.IO.BinaryWriter]::new($file)
$writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]$sizes.Count)
$offset = 6 + 16*$sizes.Count
for ($i=0; $i -lt $sizes.Count; $i++) {
    $dimension = $sizes[$i] % 256
    $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
    $writer.Write([byte]0); $writer.Write([byte]0)
    $writer.Write([uint16]1); $writer.Write([uint16]32)
    $writer.Write([uint32]$payloads[$i].Length); $writer.Write([uint32]$offset)
    $offset += $payloads[$i].Length
}
foreach ($payload in $payloads) { $writer.Write([byte[]]$payload) }
$writer.Dispose(); $source.Dispose()
Copy-Item (Join-Path $projectRoot 'assets/icon.ico') (Join-Path $projectRoot 'web/favicon.ico')
