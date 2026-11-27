// Repository-owned Windows launch fixture, not an IDE implementation.
using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public static class SessionHost
{
    [StructLayout(LayoutKind.Sequential)] struct BasicLimits {
        public long PerProcessTime, PerJobTime; public uint Flags;
        public UIntPtr MinimumWorkingSet, MaximumWorkingSet;
        public uint ActiveProcessLimit; public UIntPtr Affinity;
        public uint PriorityClass, SchedulingClass;
    }
    [StructLayout(LayoutKind.Sequential)] struct IoCounters { public ulong A,B,C,D,E,F; }
    [StructLayout(LayoutKind.Sequential)] struct ExtendedLimits {
        public BasicLimits Basic; public IoCounters Io;
        public UIntPtr ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory;
    }
    [StructLayout(LayoutKind.Sequential)] struct StartupInfo {
        public int cb; public IntPtr reserved, desktop, title;
        public uint x,y,xSize,ySize,xChars,yChars,fill,flags;
        public ushort show,reservedCount; public IntPtr reservedBytes,input,output,error;
    }
    [StructLayout(LayoutKind.Sequential)] struct StartupInfoEx { public StartupInfo Info; public IntPtr Attributes; }
    [StructLayout(LayoutKind.Sequential)] struct ProcessInfo { public IntPtr Process,Thread; public uint ProcessId,ThreadId; }
    [StructLayout(LayoutKind.Sequential)] struct SecurityAttributes { public int Length; public IntPtr Descriptor; public int Inherit; }

    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateJobObjectW(IntPtr security,string name);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job,int kind,ref ExtendedLimits value,uint length);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetHandleInformation(IntPtr handle,out uint flags);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool IsProcessInJob(IntPtr process,IntPtr job,out bool member);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool InitializeProcThreadAttributeList(IntPtr list,int count,uint flags,ref IntPtr size);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool UpdateProcThreadAttribute(IntPtr list,uint flags,IntPtr attribute,IntPtr value,IntPtr size,IntPtr previous,IntPtr returned);
    [DllImport("kernel32.dll")] static extern void DeleteProcThreadAttributeList(IntPtr list);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcessW(string application,StringBuilder command,IntPtr processSecurity,IntPtr threadSecurity,bool inherit,uint flags,IntPtr environment,string directory,ref StartupInfoEx startup,out ProcessInfo process);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateFileW(string name,uint access,uint share,ref SecurityAttributes security,uint disposition,uint attributes,IntPtr template);
    [DllImport("kernel32.dll",SetLastError=true)] static extern uint WaitForSingleObject(IntPtr handle,uint milliseconds);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetExitCodeProcess(IntPtr process,out uint code);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateProcess(IntPtr process,uint code);
    [DllImport("kernel32.dll",SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll",SetLastError=true)] static extern bool CloseHandle(IntPtr handle);

    static void Check(bool value,string operation) { if(!value) throw new Win32Exception(Marshal.GetLastWin32Error(),operation); }
    static void Close(ref IntPtr handle) { if(handle!=IntPtr.Zero && handle!=new IntPtr(-1)) { CloseHandle(handle); handle=IntPtr.Zero; } }
    static IntPtr Job(string name,bool kill) {
        IntPtr handle=CreateJobObjectW(IntPtr.Zero,name);
        int error=Marshal.GetLastWin32Error();
        if(handle==IntPtr.Zero) throw new Win32Exception(error,"CreateJobObjectW");
        if(error==183) { CloseHandle(handle); throw new InvalidOperationException("Existing session name rejected"); }
        try {
            ExtendedLimits limits=new ExtendedLimits(); limits.Basic.Flags=kill?0x2000u:0u;
            Check(SetInformationJobObject(handle,9,ref limits,(uint)Marshal.SizeOf(typeof(ExtendedLimits))),"SetInformationJobObject");
            uint flags; Check(GetHandleInformation(handle,out flags),"GetHandleInformation");
            if((flags&1)!=0) throw new InvalidOperationException("Session handle is inheritable");
            return handle;
        } catch { CloseHandle(handle); throw; }
    }
    static IntPtr FileHandle(string path,bool input) {
        SecurityAttributes security=new SecurityAttributes(); security.Length=Marshal.SizeOf(typeof(SecurityAttributes)); security.Inherit=1;
        IntPtr handle=CreateFileW(path,input?0x80000000u:0x40000000u,3,ref security,input?3u:2u,0x80,IntPtr.Zero);
        if(handle==new IntPtr(-1)) throw new Win32Exception(Marshal.GetLastWin32Error(),"CreateFileW");
        return handle;
    }
    static IntPtr EnvironmentBlock(string session) {
        SortedDictionary<string,string> values=new SortedDictionary<string,string>(StringComparer.OrdinalIgnoreCase);
        foreach(DictionaryEntry item in Environment.GetEnvironmentVariables()) values[(string)item.Key]=(string)item.Value;
        values.Remove("UBE_IDE_SESSION");
        if(session!=null) values["UBE_IDE_SESSION"]=session;
        StringBuilder block=new StringBuilder();
        foreach(KeyValuePair<string,string> item in values) block.Append(item.Key).Append('=').Append(item.Value).Append('\0');
        block.Append('\0'); return Marshal.StringToHGlobalUni(block.ToString());
    }

    // target, environment mode, lifetime mode, child stdout, child stderr, ready file.
    // "paused" and "running" keep this owner alive until the test terminates it.
    public static int Main(string[] args) {
        IntPtr job=IntPtr.Zero,decoy=IntPtr.Zero,attributes=IntPtr.Zero,jobValue=IntPtr.Zero;
        IntPtr handles=IntPtr.Zero,environment=IntPtr.Zero,input=IntPtr.Zero,output=IntPtr.Zero,error=IntPtr.Zero;
        ProcessInfo child=new ProcessInfo(); bool initialized=false;
        try {
            if(args.Length!=6) throw new ArgumentException("Expected target, environment mode, lifetime mode, stdout, stderr, ready");
            string suffix=Guid.NewGuid().ToString("N");
            if(args[1]=="uppercase") suffix=suffix.ToUpperInvariant();
            string name="Local\\UBE.IDE."+suffix;
            string mode=args[1],lifetime=args[2],session=name;
            job=Job(name,mode!="wrongflags");
            if(mode=="collision") {
                try { decoy=Job(name,true); throw new InvalidOperationException("Collision was accepted"); }
                catch(InvalidOperationException ex) { if(ex.Message!="Existing session name rejected") throw; }
                Console.WriteLine("COLLISION_REJECTED"); return 0;
            }
            if(mode=="missing") session=null;
            else if(mode=="malformed") session="Local\\UBE.IDE.invalid";
            else if(mode=="unrelated" || mode=="stale") {
                session="Local\\UBE.IDE."+Guid.NewGuid().ToString("N"); decoy=Job(session,true);
                if(mode=="stale") Close(ref decoy);
            } else if(mode!="valid" && mode!="uppercase" && mode!="wrongflags") throw new ArgumentException("Unknown environment mode");
            if(lifetime!="normal" && lifetime!="paused" && lifetime!="running" && lifetime!="suspend-close" && lifetime!="debug") throw new ArgumentException("Unknown lifetime mode");
            input=FileHandle("NUL",true); output=FileHandle(args[3],false); error=FileHandle(args[4],false);
            IntPtr size=IntPtr.Zero; InitializeProcThreadAttributeList(IntPtr.Zero,2,0,ref size);
            if(size==IntPtr.Zero) throw new InvalidOperationException("Missing attribute-list size");
            attributes=Marshal.AllocHGlobal(size);
            Check(InitializeProcThreadAttributeList(attributes,2,0,ref size),"InitializeProcThreadAttributeList"); initialized=true;
            jobValue=Marshal.AllocHGlobal(IntPtr.Size); Marshal.WriteIntPtr(jobValue,job);
            Check(UpdateProcThreadAttribute(attributes,0,new IntPtr(0x2000d),jobValue,new IntPtr(IntPtr.Size),IntPtr.Zero,IntPtr.Zero),"Atomic job list");
            handles=Marshal.AllocHGlobal(3*IntPtr.Size);
            Marshal.WriteIntPtr(handles,0,input); Marshal.WriteIntPtr(handles,IntPtr.Size,output); Marshal.WriteIntPtr(handles,2*IntPtr.Size,error);
            Check(UpdateProcThreadAttribute(attributes,0,new IntPtr(0x20002),handles,new IntPtr(3*IntPtr.Size),IntPtr.Zero,IntPtr.Zero),"Inherited stdio list");
            environment=EnvironmentBlock(session);
            StartupInfoEx startup=new StartupInfoEx(); startup.Info.cb=Marshal.SizeOf(typeof(StartupInfoEx)); startup.Info.flags=0x100;
            startup.Info.input=input;startup.Info.output=output;startup.Info.error=error;startup.Attributes=attributes;
            uint creation=0x00080000|0x00000400|0x08000000;
            if(lifetime=="paused" || lifetime=="suspend-close" || lifetime=="debug") creation|=4;
            Check(CreateProcessW(Path.GetFullPath(args[0]),new StringBuilder("\""+Path.GetFullPath(args[0])+"\""),IntPtr.Zero,IntPtr.Zero,true,creation,environment,null,ref startup,out child),"CreateProcessW");
            Close(ref input);Close(ref output);Close(ref error);
            bool member;Check(IsProcessInJob(child.Process,job,out member),"IsProcessInJob");
            if(!member) throw new InvalidOperationException("Child missing atomic job membership");
            Console.WriteLine("CHILD="+child.ProcessId); Console.WriteLine("MEMBER=1");Console.WriteLine("JOB_INHERIT=0"); Console.Out.Flush();
            File.WriteAllText(args[5]+".pending",child.ProcessId.ToString(),new UTF8Encoding(false));
            File.Move(args[5]+".pending",args[5]);
            if(lifetime=="suspend-close") {
                Close(ref job);
                Console.WriteLine("STATUS=IDE session ended before resume; child terminated without running source.");
            }
            if(lifetime=="debug") {
                DateTime deadline=DateTime.UtcNow.AddSeconds(30);
                while(!File.Exists(args[5]+".resume")) {
                    if(DateTime.UtcNow>=deadline) throw new InvalidOperationException("Debug resume deadline");
                    System.Threading.Thread.Sleep(10);
                }
                if(WaitForSingleObject(child.Process,0)!=258) throw new InvalidOperationException("Paused child exited before resume");
                if(ResumeThread(child.Thread)!=1) throw new Win32Exception(Marshal.GetLastWin32Error(),"ResumeThread");
                Console.WriteLine("STATUS=DEBUG_RESUMED");
            }
            uint waited=WaitForSingleObject(child.Process,lifetime=="normal" || lifetime=="suspend-close" || lifetime=="debug"?30000u:120000u);
            if(waited!=0) { TerminateProcess(child.Process,124); WaitForSingleObject(child.Process,5000); throw new InvalidOperationException("Child deadline or wait failure"); }
            uint status;Check(GetExitCodeProcess(child.Process,out status),"GetExitCodeProcess");
            Console.WriteLine("EXIT="+status); return 0;
        } catch(Exception ex) { Console.Error.WriteLine("HOST: "+ex.Message); return 120; }
        finally {
            if(child.Process!=IntPtr.Zero && WaitForSingleObject(child.Process,0)==258) { TerminateProcess(child.Process,124); WaitForSingleObject(child.Process,5000); }
            Close(ref child.Thread);Close(ref child.Process);Close(ref input);Close(ref output);Close(ref error);Close(ref decoy);Close(ref job);
            if(initialized) DeleteProcThreadAttributeList(attributes);
            if(attributes!=IntPtr.Zero) Marshal.FreeHGlobal(attributes);
            if(jobValue!=IntPtr.Zero) Marshal.FreeHGlobal(jobValue);
            if(handles!=IntPtr.Zero) Marshal.FreeHGlobal(handles);
            if(environment!=IntPtr.Zero) Marshal.FreeHGlobal(environment);
        }
    }
}
