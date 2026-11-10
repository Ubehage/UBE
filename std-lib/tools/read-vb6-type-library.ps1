param(
    [string]$Library = 'C:\Windows\SysWOW64\msvbvm60.dll',
    [string]$Output = ''
)
$ErrorActionPreference = 'Stop'
# Reads installed type metadata without registering or executing the library.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using TYPEATTR = System.Runtime.InteropServices.ComTypes.TYPEATTR;
using FUNCDESC = System.Runtime.InteropServices.ComTypes.FUNCDESC;
public static class TypeLibraryReader {
    [DllImport("oleaut32.dll", CharSet=CharSet.Unicode, PreserveSig=false)]
    public static extern void LoadTypeLibEx(string path, int registration, out ITypeLib library);
    public static int Count(object value) { return ((ITypeLib)value).GetTypeInfoCount(); }
    public static ITypeInfo Info(object value, int index) { ITypeInfo info; ((ITypeLib)value).GetTypeInfo(index, out info); return info; }
    public static string Name(object value) { string name, doc, help; int context; ((ITypeInfo)value).GetDocumentation(-1, out name, out doc, out context, out help); return name; }
    public static TYPEATTR Attr(object value) { var info=(ITypeInfo)value; IntPtr p; info.GetTypeAttr(out p); try { return (TYPEATTR)Marshal.PtrToStructure(p, typeof(TYPEATTR)); } finally { info.ReleaseTypeAttr(p); } }
    public static FUNCDESC Func(object value,int index) { var info=(ITypeInfo)value; IntPtr p; info.GetFuncDesc(index,out p); try { return (FUNCDESC)Marshal.PtrToStructure(p,typeof(FUNCDESC)); } finally { info.ReleaseFuncDesc(p); } }
    public static string[] Names(object value,int id,int capacity) { string[] names=new string[capacity]; int count; ((ITypeInfo)value).GetNames(id,names,capacity,out count); Array.Resize(ref names,count); return names; }
}
'@
$libraryInfo = $null
[TypeLibraryReader]::LoadTypeLibEx($Library, 2, [ref]$libraryInfo)
$entries = @()
for ($i = 0; $i -lt [TypeLibraryReader]::Count($libraryInfo); $i++) {
    $info = [TypeLibraryReader]::Info($libraryInfo, $i)
    $typeName = [TypeLibraryReader]::Name($info)
    $attr = [TypeLibraryReader]::Attr($info)
    $members = @()
    for ($j = 0; $j -lt $attr.cFuncs; $j++) {
        $function = [TypeLibraryReader]::Func($info, $j)
        $names = [TypeLibraryReader]::Names($info, $function.memid, $function.cParams + 1)
        $members += [pscustomobject]@{ name=$names[0]; kind=$function.invkind.ToString(); flags=[int]$function.wFuncFlags; parameters=@($names | Select-Object -Skip 1) }
    }
    $entries += [pscustomobject]@{ type=$typeName; kind=$attr.typekind.ToString(); members=$members }
}
$result = [pscustomobject]@{ file=[IO.Path]::GetFileName($Library); version=(Get-Item -LiteralPath $Library).VersionInfo.FileVersion; sha256=(Get-FileHash -LiteralPath $Library -Algorithm SHA256).Hash; types=$entries }
if ($Output) { $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Output -Encoding UTF8 }
else { $result | ConvertTo-Json -Depth 8 }
