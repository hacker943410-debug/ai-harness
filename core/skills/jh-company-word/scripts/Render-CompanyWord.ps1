# Read-only Word render; closes only the document and Word instance it creates.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$InputPath,
 [Parameter(Mandatory=$true)][string]$PdfPath
)
$ErrorActionPreference='Stop'
$inputFile=[IO.Path]::GetFullPath($InputPath)
$outputFile=[IO.Path]::GetFullPath($PdfPath)
if(-not(Test-Path -LiteralPath $inputFile -PathType Leaf)){throw 'INPUT_MISSING'}
if(Test-Path -LiteralPath $outputFile){throw 'OUTPUT_EXISTS_PRESERVED'}
if($inputFile -eq $outputFile){throw 'SOURCE_OVERWRITE_REFUSED'}
$sourceHash=(Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($outputFile))
$word=$null;$document=$null
try {
 $word=New-Object -ComObject Word.Application
 $word.Visible=$false;$word.DisplayAlerts=0;$word.AutomationSecurity=3
 $document=$word.Documents.Open($inputFile,$false,$true,$false)
 $document.Fields.Update() | Out-Null
 foreach($section in $document.Sections){
  foreach($footer in $section.Footers){$footer.Range.Fields.Update() | Out-Null}
 }
 $document.Repaginate()
 $pages=$document.ComputeStatistics(2)
 $document.ExportAsFixedFormat($outputFile,17)
} finally {
 if($null -ne $document){$document.Close(0);[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($document)}
 if($null -ne $word){$word.Quit(0);[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($word)}
}
if((Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash -ne $sourceHash){throw 'SOURCE_CHANGED'}
[ordered]@{status='WORD_OPEN_AND_PDF_EXPORT_PASS';inputSha256=$sourceHash.ToLowerInvariant();pdfSha256=(Get-FileHash -LiteralPath $outputFile -Algorithm SHA256).Hash.ToLowerInvariant();pages=$pages;renderer='Microsoft Word';fieldRefresh='IN_MEMORY_ONLY_NOT_SAVED_TO_DOCX';visualReview='NOT_RUN';sourceUnchanged=$true} | ConvertTo-Json
exit 0
