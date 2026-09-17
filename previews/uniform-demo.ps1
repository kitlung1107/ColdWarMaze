Add-Type -AssemblyName System.Drawing
$pixels = @(
'..........ooooooo...............',
'........oohhhhhhoo..............',
'.......ohhjjhhhhhhho............',
'......ohhjjhhhhhhhhho...........',
'.....ohhhhhohhhhhhhhho..........',
'....ohhhhhoohhhhjhhhho..........',
'....ohhhooosssssssshho..........',
'...ohhhoosssssssssssso..........',
'...ohhhosssssossssosso..........',
'...ohhhoossssossssosso..........',
'..ohhhhoosssssssssssso..........',
'..ohhho..osssssssssso...........',
'..ohhho...ossrssssso............',
'..ohho...onwwsswwno.............',
'..oho...ongwwttwgno.............',
'..oo...onngnwttwgnno............',
'......onnngnwttgnnnno...........',
'......onnngnwtngnggno...........',
'.....onnnngnttngngbno....oooll...',
'.....onnnngntvngnggno..soffflu...',
'.....onnnngnttngnnnnoossoffflu...',
'.....onnnngnvtngnnnnnnssoooll...',
'.....onnnngnttngnnnnnno.........',
'.....onnnngntnngnnnnoo..........',
'.....onwnnngnngnnnno............',
'.....ossoonnngnnnno.............',
'.....ossoopppqppppo.............',
'......ooopqqqqqqqqpo............',
'........opppqpppqppo............',
'.......oppppqpppqpppo...........',
'.......oqqqqqqqqqqqqo...........',
'.......oppppqpppqpppo...........',
'........oooossoossoo............',
'..........oss..osso.............',
'..........oss..osso.............',
'..........onn..onno.............',
'..........onn..onno.............',
'.........onno..onno.............',
'.........onno..onno.............',
'.........onno..onno.............',
'........offfo..offfo............',
'........ofkffo.offkffo..........',
'........oooooo.oooooo..........'
)
$palette = @{
o='090d17';h='302729';j='57433d';s='f4bc94';r='d98a71';n='202940';
w='f2ecdb';g='d9b479';t='354361';v='8a99bb';b='667fa5';p='252b44';q='4c526b';
f='201e25';k='4e4141';l='eac781';u='fff3cb'
}
$bmp = [System.Drawing.Bitmap]::new(1080,720)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.Clear([System.Drawing.ColorTranslator]::FromHtml('#101828'))
$gfx.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
function Rect($x,$y,$w,$h,$hex) {
  $brush=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#'+$hex))
  $gfx.FillRectangle($brush,$x,$y,$w,$h)
  $brush.Dispose()
}
function Text($text,$x,$y,$size,$hex) {
  $font=[System.Drawing.Font]::new('Microsoft JhengHei',$size)
  $brush=[System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml('#'+$hex))
  $gfx.DrawString($text,$font,$brush,$x,$y)
  $brush.Dispose(); $font.Dispose()
}
function Student($px,$py,$scale) {
  for($y=0;$y -lt $pixels.Count;$y++) {
    for($x=0;$x -lt $pixels[$y].Length;$x++) {
      $key=[string]$pixels[$y][$x]
      if($palette.ContainsKey($key)){Rect ($px+$x*$scale) ($py+$y*$scale) $scale $scale $palette[$key]}
    }
  }
}
Text '校服與電筒 · 造型預覽' 46 30 26 'f1ead9'
Text '參考圖像素化 / 尚未套用到遊戲' 49 80 13 'a2aec2'
Rect 42 129 598 535 '172238'
for($y=145;$y -lt 660;$y+=36){Rect 43 $y 596 1 '202d44'}
for($x=65;$x -lt 635;$x+=44){Rect $x 130 1 532 '1d2940'}
# Stepped warm beam, behind the character and its torch.
for($i=0;$i -lt 14;$i++) {
  $hex= @('756246','705e43','6b5a41','66563e','61523b','5b4e39','554936','504533','494030','433c2e','3e382c','37332a','302e28','292927')[$i]
  Rect (393+$i*17) (341-$i*9) 17 (32+$i*18) $hex
}
Rect 182 601 210 10 '0d1423'
Student 148 151 10
Text '放大造型' 65 621 14 'b7c2d4'
Text '深藍金邊校服' 690 146 21 'e2be83'
Text '白襯衫、斜紋領帶、胸前校章' 691 193 14 'd9dfeb'
Text '深色格紋裙、長襪、黑皮鞋' 691 225 14 'd9dfeb'
Text '深棕馬尾' 690 288 21 'e2be83'
Text '保留參考圖的側身探索造型' 691 333 14 'd9dfeb'
Text '黑色手提電筒' 690 398 21 'e2be83'
Text '奶黃色燈面、暖黃扇形光束' 691 443 14 'd9dfeb'
Text '縮小辨識預覽' 690 515 16 'a2aec2'
Student 705 552 2
Student 817 534 3
Text 'DEMO 01' 915 672 12 '718098'
$bmp.Save((Join-Path $PSScriptRoot 'uniform-demo.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$gfx.Dispose(); $bmp.Dispose()
