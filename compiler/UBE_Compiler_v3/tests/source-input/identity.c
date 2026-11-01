/* Included by probe.c: reuse its exact layout, allocator and byte assertions.
   This tests the private paired construction entry, not project publication. */
extern int32_t source_identified_file(void**,int32_t,struct document*,void**,struct failure*,int32_t*,int32_t*);
static int same_identity(void* left,void* right) {
    if (ube_value_array_length(&left)!=16 || ube_value_array_length(&right)!=16) return 0;
    for (int32_t i=0;i<16;++i) if(get(left,i)!=get(right,i)) return 0;
    return 1;
}
static int identified_files(void) {
    WCHAR directory[MAX_PATH],path[MAX_PATH];
    CHECK(GetTempPathW(MAX_PATH,directory)!=0);
    CHECK(swprintf(path,MAX_PATH,L"%lsUBE-identified-%lu.bas",directory,(unsigned long)GetCurrentProcessId())>0);
    HANDLE file=CreateFileW(path,GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,NULL,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,NULL);
    CHECK(file!=INVALID_HANDLE_VALUE);
    const uint8_t data[]={0xef,0xbb,0xbf,0xc3,0xa9,13,10,65};DWORD wrote=0;
    CHECK(WriteFile(file,data,sizeof data,&wrote,NULL)&&wrote==sizeof data&&CloseHandle(file));
    char utf8[MAX_PATH*4];int length=WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,path,-1,utf8,sizeof utf8,NULL,NULL);CHECK(length>0);
    void* bytes=NULL;void* identity=NULL;void* repeated=NULL;struct document document={0};
    root roots[4]={{0}};struct failure failure={0};int32_t domain=0,token=0;
    CHECK(ube_gc_root_enter(&roots[0],&bytes)&&ube_gc_root_enter(&roots[1],&document.bytes)&&ube_gc_root_enter(&roots[2],&identity)&&ube_gc_root_enter(&roots[3],&repeated));
    CHECK(array(&bytes,(const uint8_t*)utf8,length-1));seed(77);
    CHECK(source_identified_file(&bytes,100,&document,&identity,&failure,&domain,&token));
    CHECK(equal(document.bytes,data,sizeof data)&&document.content==3&&document.scalars==4&&document.lines==2&&failure.kind==0&&domain==0&&token==0&&ube_err_number()==77);
    CHECK(ube_value_array_length(&identity)==16);
    CHECK(source_identified_file(&bytes,100,&document,&repeated,&failure,&domain,&token));
    CHECK(identity!=repeated&&same_identity(identity,repeated)&&domain==0&&token==0);
#ifdef OBSERVE_INPUT
    CHECK(ube_file_test_open_handles()==0&&source_test_root_count()==4);
    struct document old=document;
    ube_file_test_inject(2);
    CHECK(!source_identified_file(&bytes,100,&document,&repeated,&failure,&domain,&token));
    CHECK(failure.kind==6&&domain==5&&token==0&&same_document(document,old)&&equal(document.bytes,data,sizeof data)&&same_identity(identity,repeated));
    ube_file_test_inject(0);
    ube_file_test_inject(6);
    CHECK(!source_identified_file(&bytes,100,&document,&repeated,&failure,&domain,&token));
    CHECK(failure.kind==6&&domain==7&&token!=0&&same_document(document,old)&&equal(document.bytes,data,sizeof data)&&ube_file_test_open_handles()==1);
    extern int32_t ube_file_try_close(int32_t*,int32_t*);
    ube_file_test_inject(0);CHECK(ube_file_try_close(&token,&domain)&&token==0);
    void* prior=repeated;
    ube_gc_test_fail_next_allocations(2);ube_file_test_inject(6);
    CHECK(!source_identified_file(&bytes,100,&document,&repeated,&failure,&domain,&token));
    CHECK(failure.kind==6&&domain==8&&token!=0&&repeated==prior&&same_document(document,old)&&equal(document.bytes,data,sizeof data)&&ube_file_test_open_handles()==1);
    ube_file_test_inject(0);CHECK(ube_file_try_close(&token,&domain)&&token==0);
    CHECK(!source_identified_file(&bytes,0,&document,&repeated,&failure,&domain,&token));
    CHECK(failure.kind==2&&domain==4&&token==0&&repeated==prior&&same_document(document,old)&&ube_file_test_open_handles()==0);
    const int32_t sizes[]={0,1,31,4095,4096,4097,16384,65536};uint8_t block[4096];memset(block,65,sizeof block);
    for(size_t index=0;index<sizeof sizes/sizeof *sizes;++index){
        int32_t n=sizes[index];
        file=CreateFileW(path,GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL);CHECK(file!=INVALID_HANDLE_VALUE);
        for(int32_t offset=0;offset<n;){DWORD requested=n-offset>4096?4096:(DWORD)(n-offset);CHECK(WriteFile(file,block,requested,&wrote,NULL)&&wrote==requested);offset+=(int32_t)wrote;}
        CHECK(CloseHandle(file));
        struct observations before=observed;int32_t reads=ube_file_test_reads();
        seed(77);CHECK(source_file(&bytes,n,&document,&failure,&domain,&token));
        size_t ordinary_copies=observed.copied-before.copied;int32_t ordinary_reads=ube_file_test_reads()-reads;
        before=observed;reads=ube_file_test_reads();
        CHECK(source_identified_file(&bytes,n,&document,&repeated,&failure,&domain,&token));
        CHECK(failure.kind==0&&domain==0&&token==0&&document.scalars==n&&document.lines==1&&ube_err_number()==77);
        CHECK(observed.copied-before.copied==ordinary_copies+16&&ube_file_test_reads()-reads==ordinary_reads&&observed.feeds-before.feeds==(size_t)n);
        CHECK(same_identity(identity,repeated)&&source_test_root_count()==4&&ube_file_test_open_handles()==0);
        for(int32_t i=0;i<n;++i)CHECK(get(document.bytes,i)==65);
        printf("{\"kind\":\"identified\",\"n\":%d,\"ordinaryCopiedBytes\":%zu,\"identifiedCopiedBytes\":%zu,\"ordinaryReadCalls\":%d,\"identifiedReadCalls\":%d}\n",n,ordinary_copies,observed.copied-before.copied,ordinary_reads,ube_file_test_reads()-reads);
    }
    /* Actual root exhaustion before managed entry: fresh caller status and old
       document/identity survive, with no reader admitted or close owner lost. */
    root* pressure=calloc(1048576,sizeof(root));CHECK(pressure!=NULL);size_t admitted=0;
    while(admitted<1048576&&ube_gc_root_enter(&pressure[admitted],&bytes))++admitted;
    CHECK(admitted==1048572&&source_test_root_count()==1048576);
    old=document;prior=repeated;failure=(struct failure){5,{0,0,1,1}};domain=0;
    CHECK(!source_identified_file(&bytes,65536,&document,&repeated,&failure,&domain,&token));
    CHECK(failure.kind==5&&domain==0&&token==0&&repeated==prior&&same_document(document,old)&&ube_err_number()==7&&ube_file_test_open_handles()==0);
    while(admitted>0){--admitted;CHECK(ube_gc_root_leave(&pressure[admitted]));}free(pressure);
    CHECK(source_test_root_count()==4);
    CHECK(source_identified_file(&bytes,65536,&document,&repeated,&failure,&domain,&token)&&failure.kind==0&&domain==0&&token==0);
#endif
    CHECK(DeleteFileW(path));
    for(int i=3;i>=0;--i)CHECK(ube_gc_root_leave(&roots[i]));
    ube_gc_collect();CHECK(ube_gc_live_allocation_bytes()==0);return 0;
}
