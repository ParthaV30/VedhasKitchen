# Image optimization script for Vedha's Kitchen
# Requirements: ImageMagick (magick.exe) OR Google cwebp (optional)
# This script will generate resized JPEG and WebP variants for images in the assets folder.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$projectRoot = Split-Path -Parent $scriptDir
$assetsDir = Join-Path $projectRoot "assets"

if (-not (Test-Path $assetsDir)) {
    Write-Host "Assets directory not found at $assetsDir" -ForegroundColor Yellow
    exit 0
}

Set-Location $assetsDir

$images = Get-ChildItem -Path $assetsDir -Include *.jpg,*.jpeg,*.png -File
if (-not $images) {
    Write-Host "No source images found in $assetsDir" -ForegroundColor Yellow
    exit 0
}

foreach ($img in $images) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($img.Name)
    $ext = $img.Extension.ToLower()

    # sizes in px (width)
    $sizes = @(400, 800)

    foreach ($w in $sizes) {
        $outJpg = "${base}-${w}.jpg"
        $outWebp = "${base}-${w}.webp"

        # Use ImageMagick if available
        if (Get-Command magick -ErrorAction SilentlyContinue) {
            Write-Host "Creating $outJpg and $outWebp from $($img.Name) with width $w"
            magick convert "$($img.FullName)" -strip -interlace Plane -quality 80 -resize ${w}x "$outJpg"
            magick convert "$outJpg" -quality 80 "$outWebp"
        }
        # Fallback to cwebp if available (needs a JPEG already)
        elseif (Get-Command cwebp -ErrorAction SilentlyContinue) {
            Write-Host "Creating $outJpg using System.Drawing and $outWebp using cwebp (requires installed .NET)."
            # Attempt to create resized JPEG using PowerShell + .NET
            try {
                $image = [System.Drawing.Image]::FromFile($img.FullName)
                $ratio = $image.Width / $image.Height
                $newHeight = [int]([math]::Round($w / $ratio))
                $thumb = New-Object System.Drawing.Bitmap $w, $newHeight
                $g = [System.Drawing.Graphics]::FromImage($thumb)
                $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.DrawImage($image, 0, 0, $w, $newHeight)
                $thumb.Save($outJpg, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $g.Dispose(); $thumb.Dispose(); $image.Dispose()
                # convert to webp
                cwebp -q 80 $outJpg -o $outWebp | Out-Null
            } catch {
                Write-Host "Failed creating resized JPEG for $($img.Name): $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "Neither ImageMagick (magick) nor cwebp found. Please install one to generate WebP variants." -ForegroundColor Yellow
            break
        }
    }
}

Write-Host "Image optimization script finished. If conversions were successful, add appropriate srcset/picture tags to your HTML and commit the generated files." -ForegroundColor Green
