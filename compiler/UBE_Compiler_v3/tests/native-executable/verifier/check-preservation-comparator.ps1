param([Parameter(Mandatory=$true)][string] $OutputDirectory)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'preservation-snapshot.ps1')
$directory = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ([guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($directory) | Out-Null
$path = Join-Path $directory 'old.exe'
[IO.File]::WriteAllBytes($path, [byte[]](1, 2, 3, 4))
Set-Content -LiteralPath $path -Stream 'ube-preservation-test' -Value 'original stream' -NoNewline
[IO.File]::SetCreationTimeUtc($path, [DateTime]::new(2019, 1, 2, 3, 4, 6, [DateTimeKind]::Utc))
[IO.File]::SetLastWriteTimeUtc($path, [DateTime]::new(2020, 1, 2, 3, 4, 6, [DateTimeKind]::Utc))
$original = Snapshot $path
if (-not (Same $original (Snapshot $path))) { throw 'Unchanged file failed the comparison' }
[IO.File]::SetLastWriteTimeUtc($path, [DateTime]::new(2021, 1, 2, 3, 4, 6, [DateTimeKind]::Utc))
$mutated = Snapshot $path
if ($original.Hash -ne $mutated.Hash -or $original.LastWrite -eq $mutated.LastWrite -or (Same $original $mutated)) {
    throw 'Comparator missed a metadata-only change'
}
[IO.File]::SetLastWriteTimeUtc($path, [DateTime]::new(2020, 1, 2, 3, 4, 6, [DateTimeKind]::Utc))
[IO.File]::SetCreationTimeUtc($path, [DateTime]::new(2018, 1, 2, 3, 4, 6, [DateTimeKind]::Utc))
$creationChanged = Snapshot $path
if ($original.Creation -eq $creationChanged.Creation -or (Same $original $creationChanged)) {
    throw 'Comparator missed a creation-time change'
}
$differentCreation = $creationChanged.Creation; $creationChanged.Creation = $original.Creation
if (-not (Same $original $creationChanged)) { throw 'Creation-time control changed another compared property' }
[IO.File]::SetCreationTimeUtc($path, [DateTime]::new(2019, 1, 2, 3, 4, 6, [DateTimeKind]::Utc))
$previousAttributes = [IO.File]::GetAttributes($path)
[IO.File]::SetAttributes($path, ($previousAttributes -bxor [IO.FileAttributes]::Hidden))
$attributesChanged = Snapshot $path
if ($original.Hash -ne $attributesChanged.Hash -or $original.Attributes -eq $attributesChanged.Attributes -or (Same $original $attributesChanged)) {
    throw 'Comparator missed an attributes-only change'
}
$differentAttributes = $attributesChanged.Attributes; $attributesChanged.Attributes = $original.Attributes
if (-not (Same $original $attributesChanged)) { throw 'Attributes control changed another compared property' }
$attributesChanged.Attributes = $differentAttributes
[IO.File]::SetAttributes($path, $previousAttributes)
$originalAcl = Get-Acl -LiteralPath $path
$changedAcl = Get-Acl -LiteralPath $path
$account = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$rule = [Security.AccessControl.FileSystemAccessRule]::new($account, 'Read', 'Allow')
$changedAcl.AddAccessRule($rule)
Set-Acl -LiteralPath $path -AclObject $changedAcl
$securityChanged = Snapshot $path
if ($original.Hash -ne $securityChanged.Hash -or $original.Security -eq $securityChanged.Security -or (Same $original $securityChanged)) {
    throw 'Comparator missed a security-descriptor change'
}
$differentSecurity = $securityChanged.Security; $securityChanged.Security = $original.Security
if (-not (Same $original $securityChanged)) { throw 'Security control changed another compared property' }
$securityChanged.Security = $differentSecurity
Set-Acl -LiteralPath $path -AclObject $originalAcl
Set-Content -LiteralPath $path -Stream 'ube-preservation-test' -Value 'modified stream' -NoNewline
[IO.File]::SetLastWriteTimeUtc($path, [DateTime]::new(2020, 1, 2, 3, 4, 6, [DateTimeKind]::Utc))
$streamChanged = Snapshot $path
if ($original.Hash -ne $streamChanged.Hash -or $original.Stream -eq $streamChanged.Stream -or (Same $original $streamChanged)) {
    throw 'Comparator missed a named-stream change'
}
$differentStream = $streamChanged.Stream; $streamChanged.Stream = $original.Stream
if (-not (Same $original $streamChanged)) { throw 'Stream control changed another compared property' }
$streamChanged.Stream = $differentStream
$oldIdentity = $streamChanged.Identity
[IO.File]::Move($path, (Join-Path $directory 'moved.exe'))
[IO.File]::WriteAllBytes($path, [byte[]](1, 2, 3, 4))
Set-Content -LiteralPath $path -Stream 'ube-preservation-test' -Value 'original stream' -NoNewline
[IO.File]::SetCreationTimeUtc($path, [DateTime]::new(2019, 1, 2, 3, 4, 6, [DateTimeKind]::Utc))
[IO.File]::SetLastWriteTimeUtc($path, [DateTime]::new(2020, 1, 2, 3, 4, 6, [DateTimeKind]::Utc))
$replaced = Snapshot $path
if ($original.Hash -ne $replaced.Hash -or $oldIdentity -eq $replaced.Identity -or (Same $original $replaced)) {
    throw 'Comparator missed a replacement with the same bytes'
}
$differentIdentity = $replaced.Identity; $replaced.Identity = $original.Identity
if (-not (Same $original $replaced)) { throw 'Identity control changed another compared property' }
$replaced.Identity = $differentIdentity
Write-Output 'Unchanged snapshot matched; creation time, last-write time, attribute, security, stream and identity mutations were rejected.'
