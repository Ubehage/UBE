Begin-Project 'duplicate-folded-name-preserves-result'
$kelvin=[string][char]0x212A
$source="UBE SOURCE 1 MODULE`nAttribute UBE_Name = `"Broken`"`nPublic Sub Main()`n    Dim K As Long`n    Dim "+$kelvin+" As Long`nEnd Sub`n"
Add-Source 0 app Broken Broken.bas $source
$script:p.outcome='error'
$first=W first-name K 'Dim K As Long'
$later=W duplicate-name $kelvin ('Dim '+$kelvin+' As Long')
$script:p.failure=[ordered]@{class='DuplicateName';category='declaration';at=$later;related=@($first);preserveResultFixture='scalar-context-and-storage';newResult=$null;newDeclarationsPublished=0;newFactsPublished=0;oldOwnersPreserved=$true}
Finish-Project
