[CmdletBinding()]
param (
  [Alias("album")]
  [Parameter(Mandatory=$true)]
  [string]
  $albumname,

  [Alias("path")]
  [Parameter(Mandatory=$true)]
  [ValidateScript({
    if( -Not ($_ | Test-Path) ){
      throw "File or folder does not exist"
    }
    return $true
  })]
  [System.IO.FileInfo]
  $sourcePath,

  [Parameter(Mandatory=$false)]
  [ValidateScript({
    if( -Not ($_ | Test-Path) ){
      throw "File or folder does not exist"
    }
    return $true
  })]
  [System.IO.FileInfo]
  $destinationPath, 

  [Parameter(Mandatory=$true)]
  [ValidateSet('copy','move')]
  [string]
  $copyOrMove,

  [Parameter(Mandatory=$false)]
  [switch]
  $recursive,

  [Parameter(Mandatory=$false)]
  [double]
  $offsetHour,

  [Parameter(Mandatory=$false)]
  [double]
  $offsetMinute,

  [Parameter(Mandatory=$false)]
  [double]
  $offsetSeconds,

  [Parameter(Mandatory=$false)]
  [switch]
  $haltOnFirstone,

  [Parameter(
    Mandatory=$false,
    HelpMessage="A timezone is defined like: +02:00 or: -10:00")]
  [string]
  $newTimezone,

  [Parameter(Mandatory=$false)]
  [ValidateScript({
    if( -Not ($_ | Test-Path) ){
      throw "File or folder does not exist"
    }
    return $true
  })]
  [System.IO.FileInfo]
  $exiftoolPath = ".\tools\exiftool.exe",

  [Parameter(Mandatory=$false)]
  [switch]
  $whatsAppImages
)
$files = Get-ChildItem -path $sourcePath -File -Recurse:$recursive

$firstOne = $true
if (-not ($destinationPath) ) {
    $destinationPath = $sourcePath
}

foreach ($file in $files){
  [string]$sCreateDate = & $exiftoolPath -CreateDate $file.fullname
  [int]$duplicationNumber = 0
  [string]$newFileName = ""
  [string]$fileExtention = $file.Extension
  if ($whatsAppImages) {
    $fileName = $file.BaseName
    $date = $fileName.Split(" ")[2]
    $time = $fileName.Split(" ")[4]
    $dtCreateDate = [datetime]::parseexact("$date $time", 'yyyy-MM-dd HH.mm.ss', $null)
    if ($firstOne) {
      Write-host "You have selected whatapp images. This is the time we are using: $dtCreateDate. For file: $($file.name)"
    }
  } else {
    if ($sCreateDate) {
      $sCreateDate = $sCreateDate.replace("Create Date                     : ","")
      if (-not($sCreateDate.StartsWith("0000"))){
        [datetime]$dtCreateDate = [datetime]::parseexact($sCreateDate, 'yyyy:MM:dd HH:mm:ss', $null)
      } else {
        $sCreateDate = & $exiftoolPath -FileCreateDate $file.fullname
        $sCreateDate = $sCreateDate.replace("File Creation Date/Time         : ","")
        [datetime]$dtCreateDate = [datetime]::parseexact($sCreateDate, 'yyyy:MM:dd HH:mm:sszzz', $null)
      }
    } else {
      $sCreateDate = & $exiftoolPath -FileCreateDate $file.fullname
      $sCreateDate = $sCreateDate.replace("File Creation Date/Time         : ","")
      [datetime]$dtCreateDate = [datetime]::parseexact($sCreateDate, 'yyyy:MM:dd HH:mm:sszzz', $null)
    }
    if (($offsetHour -or $offsetMinute -or $offsetSeconds) -and $firstOne) {
      Write-host "You have selected a offset. This is what we are doing:"
      Write-host " - Original time: $dtCreateDate"
    } elseif ($firstOne) {
      Write-host "You have not selected a offset. This is the time we are using: $dtCreateDate. For file: $($file.name)"
    }
    if ($offsetHour){    $dtCreateDate = $dtCreateDate.AddHours($offsetHour) }
    if ($offsetMinute){  $dtCreateDate = $dtCreateDate.AddMinutes($offsetMinute) }
    if ($offsetSeconds){ $dtCreateDate = $dtCreateDate.AddSeconds($offsetSeconds) }
    if (( $offsetHour -or $offsetMinute -or $offsetSeconds ) -and $firstOne) {
      Write-host " - (New) using time: $dtCreateDate"
    }
  }
  if ($haltOnFirstone -and $firstOne) {
    Pause
  }

  do {
    $newFileName = "$destinationPath\$albumName`_$($dtCreateDate.ToString("yyyyMMdd_HHmmss"))_{0:d3}$fileExtention" -f $duplicationNumber
    $duplicationNumber ++
  } until ( -not (test-path $newFileName) )
  
  switch ($copyOrMove) {
    "copy" { Copy-Item -Path $file.fullname -Destination $newFileName }
    "move" { Move-Item -Path $file.fullname -Destination $newFileName }
  }
  Write-host "We are $copyOrMove`ing file: $file to: $newFileName" -NoNewline

  if ($offsetHour -or $offsetMinute -or $offsetSeconds -or $whatsAppImages) {
    $sNewCreateDate = $dtCreateDate.ToString("yyyy:MM:dd HH:mm:ss")
    if ($newTimezone){
      & $exiftoolPath "-DateTimeOriginal=$sNewCreateDate" "-OffsetTime=$newTimezone" -overwrite_original_in_place $newFileName
    } else {
      & $exiftoolPath "-DateTimeOriginal=$sNewCreateDate" -overwrite_original_in_place $newFileName
    }
    Write-host " and updating the DateTaken field." -NoNewline
  }
  Write-host ""
  $firstOne = $false
}
