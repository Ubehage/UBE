# Test-only instrumentation. Production runtime source is never edited.
function New-SignedIntegerObservedRuntime([string]$Repo,[string]$Run,$Selection){
 $source=Join-Path $Repo 'bootstrap/runtime/bootstrap_runtime.c'
 $runtime=[IO.File]::ReadAllText($source).Replace([string][char]13,'')
 $admission=@'
        if(__atomic_compare_exchange_n(&ube_root_registry.state,&current,current+1,0,
                __ATOMIC_SEQ_CST,__ATOMIC_SEQ_CST))return 1;
'@
 $removal='(void)__atomic_fetch_sub(&ube_root_registry.state,UINT64_C(1),__ATOMIC_SEQ_CST);'
 $clear='__atomic_store_n(&ube_root_registry.state,UBE_ROOT_CLOSED,__ATOMIC_SEQ_CST);'
 foreach($site in @($admission,$removal,$clear)){if([regex]::Matches($runtime,[regex]::Escape($site)).Count -ne 1){throw 'Exact signed integer root-counter mutation required'}}
 if([regex]::Matches($runtime,'__atomic_(?:compare_exchange_n|fetch_sub|store_n)\(&ube_root_registry\.state,').Count -ne 3){throw 'Root-counter mutation inventory changed'}
 $runtime=$runtime.Replace($admission,$admission.Replace('return 1;','{index_root_changed((size_t)((current+1)&UBE_ROOT_COUNT_MASK));return 1;}'))
 $runtime=$runtime.Replace($removal,'uint64_t index_previous=__atomic_fetch_sub(&ube_root_registry.state,UINT64_C(1),__ATOMIC_SEQ_CST); index_root_changed((size_t)((index_previous-1)&UBE_ROOT_COUNT_MASK));')
 $runtime=$runtime.Replace($clear,$clear+' index_root_changed(0);')
 $tail=@'

size_t index_root_count(void) { return ube_gc_root_count; }
size_t index_root_limit(void) { return UBE_GC_MAX_ROOTS; }
size_t index_array_header(void) { return sizeof(struct ube_array); }
size_t index_gc_header(void) { return sizeof(struct ube_gc_header); }
'@
 $runtime="#include <stddef.h>`nvoid index_root_changed(size_t);`n"+$runtime+$tail
 $first='ube_gc_live_bytes += layout->size;';$second='ube_gc_live_bytes += size;'
 foreach($site in @($first,$second)){if([regex]::Matches($runtime,[regex]::Escape($site)).Count -ne 1){throw 'Exact GC payload increment required'}}
 $mutations=@([regex]::Matches($runtime,'(?m)^\s*ube_gc_live_bytes\s*(?:\+\+|--|<<=|>>=|[+*/%&|^-]=|=(?!=))[^;\r\n]*;')|ForEach-Object {$_.Value.Trim()})
 $expected=@('ube_gc_live_bytes += layout->size;','ube_gc_live_bytes += size;','ube_gc_live_bytes -= item->payload_size;','ube_gc_live_bytes -= item->payload_size;','ube_gc_live_bytes = 0;')
 if((($mutations|Sort-Object)-join "`n") -cne (($expected|Sort-Object)-join "`n")){throw 'GC payload mutation inventory changed'}
 if([regex]::Matches($runtime,'(?:\+\+|--)\s*ube_gc_live_bytes|(?<!&)&(?!&)\s*ube_gc_live_bytes').Count){throw 'GC payload counter address escape/prefix mutation changed'}
 $runtime="#include <stddef.h>`nvoid name_heap_changed(size_t);`n"+$runtime.Replace($first,$first+' name_heap_changed(ube_gc_live_bytes);').Replace($second,$second+' name_heap_changed(ube_gc_live_bytes);')
 $directory=Join-Path $Run 'observer';$null=New-Item -ItemType Directory -Path $directory -Force
 $generated=Join-Path $directory 'runtime-observed.c';$ir=Join-Path $directory 'runtime-observed.ll';$object=Join-Path $directory 'runtime-observed.o'
 [IO.File]::WriteAllText($generated,$runtime,(New-Object Text.UTF8Encoding($false)))
 $frozen=Join-Path $Repo 'bootstrap/out/name-probes/observers/e6b6c806f8a1480195681b974754b147/runtime-observed.c';$equivalent=$null
 if(Test-Path -LiteralPath $frozen){$equivalent=(Get-ArtifactIdentity $generated).sha256 -ceq (Get-ArtifactIdentity $frozen).sha256}
 $arguments=@('--target=x86_64-w64-windows-gnu','-O2','-std=c11','-Wall','-Wextra','-Werror','-I',(Join-Path $Repo 'bootstrap/runtime'),'-include',(Join-Path $Repo 'std-lib/tests/managed-storage/copy-probe.h'),'-S','-emit-llvm',$generated,'-o',$ir)
 $compile=Invoke-BoundedProcess $Selection.clang.path $arguments $Repo 90
 if($compile.timedOut -or $compile.exit -ne 0){throw "Signed integer observer compile failed: $($compile.stderr)"}
 $link=Invoke-BoundedProcess $Selection.clang.path @('--target=x86_64-w64-windows-gnu','-O2','-c','-x','ir',$ir,'-o',$object) $Repo 90
 if($link.timedOut -or $link.exit -ne 0){throw "Signed integer observer object failed: $($link.stderr)"}
 return [pscustomobject]@{source=(Get-ArtifactIdentity $source);generated=(Get-ArtifactIdentity $generated);ir=(Get-ArtifactIdentity $ir);object=(Get-ArtifactIdentity $object);rootMutationSites=3;heapMutationInventory=$mutations;increasingHeapSites=2;equivalentToFrozenSource=$equivalent;commands=@($compile,$link);limits='Private native runtime copy. Both exact allocation increments and every actual root-count mutation call scalar/TLS-only callbacks; all five heap mutations are audited. No production source edit or wrapper-boundary-only heap estimate.'}
}
