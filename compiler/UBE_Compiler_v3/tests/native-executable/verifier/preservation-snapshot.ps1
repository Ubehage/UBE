Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class PreservationIdentity {
    [StructLayout(LayoutKind.Sequential)]
    private struct FileInfo {
        public uint Attributes, CreationLow, CreationHigh, AccessLow, AccessHigh;
        public uint WriteLow, WriteHigh, Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow;
    }
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool GetFileInformationByHandle(SafeFileHandle handle, out FileInfo info);
    public static string Read(string path) {
        using (var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete)) {
            FileInfo info;
            if (!GetFileInformationByHandle(file.SafeFileHandle, out info)) throw new System.ComponentModel.Win32Exception();
            return String.Format("{0:X8}:{1:X8}{2:X8}", info.Volume, info.IndexHigh, info.IndexLow);
        }
    }
}
'@
function Snapshot([string] $file) {
    $item = Get-Item -LiteralPath $file -Force
    return @{
        Hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
        Creation = $item.CreationTimeUtc.Ticks
        LastWrite = $item.LastWriteTimeUtc.Ticks
        Attributes = [int]$item.Attributes
        Security = (Get-Acl -LiteralPath $file).Sddl
        Identity = [PreservationIdentity]::Read($file)
        Stream = (Get-Content -LiteralPath $file -Stream 'ube-preservation-test' -Raw)
    }
}
function Same($a, $b) {
    return $a.Hash -eq $b.Hash -and $a.Creation -eq $b.Creation -and $a.LastWrite -eq $b.LastWrite -and
           $a.Attributes -eq $b.Attributes -and $a.Security -eq $b.Security -and
           $a.Identity -eq $b.Identity -and $a.Stream -eq $b.Stream
}
