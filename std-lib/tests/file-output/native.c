#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static _Thread_local int observing, write_mode, flush_mode;
static _Thread_local size_t allocations, copies, writes, flushes;
static _Thread_local HANDLE reached, release_write;
static void* observed_malloc(size_t n) { if (observing) ++allocations; return malloc(n); }
static void* observed_calloc(size_t n, size_t size) { if (observing) ++allocations; return calloc(n,size); }
static void* observed_realloc(void* p, size_t n) { if (observing) ++allocations; return realloc(p,n); }
static void observed_copy(size_t n) { if (observing) copies += n; }
static BOOL counted_write(HANDLE, LPCVOID, DWORD, LPDWORD, LPOVERLAPPED);
static BOOL counted_flush(HANDLE);
#define malloc observed_malloc
#define calloc observed_calloc
#define realloc observed_realloc
#define UBE_VALUE_OBSERVE_COPY(n) observed_copy(n)
#define UBE_FILE_WRITE counted_write
#define UBE_FILE_FLUSH counted_flush
#define UBE_FILE_TESTING
#include "../../../bootstrap/runtime/bootstrap_runtime.c"
#undef malloc
#undef calloc
#undef realloc

#ifdef UBE_OUTPUT_WRAPPERS
extern int32_t output_bridge_write(int32_t,void* const*,int32_t,int32_t,int32_t*,int32_t*);
extern int32_t output_bridge_flush(int32_t,int32_t*);
#define ube_file_try_write output_bridge_write
#define ube_file_try_flush output_bridge_flush
#endif

static BOOL counted_write(HANDLE file, LPCVOID bytes, DWORD count, LPDWORD written, LPOVERLAPPED overlapped) {
    ++writes;
    if (reached != NULL) {
        if (!SetEvent(reached) || WaitForSingleObject(release_write,5000) != WAIT_OBJECT_0) return FALSE;
    }
    if (write_mode == 1 && count > 1) count /= 2;
    if (write_mode == 2) { *written = 0; return TRUE; }
    if (write_mode == 3) {
        *written = 0; SetLastError(ERROR_DISK_FULL);
#ifdef IGNORE_FAILURE_CONTROL
        return TRUE;
#else
        return FALSE;
#endif
    }
    if (write_mode == 4) {
        BOOL result = WriteFile(file,bytes,count > 1 ? count / 2 : count,written,overlapped);
        if (!result) return result;
        SetLastError(ERROR_DISK_FULL); return FALSE;
    }
#ifdef OMIT_WRITE_CONTROL
    *written = count; return TRUE;
#else
#ifdef CHANGED_BYTE_CONTROL
    unsigned char changed[65536];
    memcpy(changed,bytes,count); if (count) changed[0] ^= 1;
    bytes = changed;
#endif
    BOOL result = WriteFile(file,bytes,count,written,overlapped);
#ifdef WRONG_COUNT_CONTROL
    if (result && *written) --*written;
#endif
    return result;
#endif
}

static BOOL counted_flush(HANDLE file) {
    ++flushes;
    if (flush_mode) { SetLastError(ERROR_WRITE_FAULT); return FALSE; }
    return FlushFileBuffers(file);
}

/* Test-only producer. Production native-build admission must instead perform
   the reviewed directory-relative guarded create before publishing this owner. */
static int32_t create_output(const wchar_t* path) {
    struct ube_file_reader* owner = calloc(1,sizeof(*owner));
    if (!owner) return 0;
    AcquireSRWLockExclusive(&ube_file_registry_lock);
    if (ube_file_last_token == INT32_MAX) { ReleaseSRWLockExclusive(&ube_file_registry_lock); free(owner); return 0; }
    owner->token = ++ube_file_last_token;
    ReleaseSRWLockExclusive(&ube_file_registry_lock);
    owner->handle = CreateFileW(path,GENERIC_WRITE,FILE_SHARE_READ,NULL,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,NULL);
    if (owner->handle == INVALID_HANDLE_VALUE) { free(owner); return 0; }
    owner->writable = 1;
    AcquireSRWLockExclusive(&ube_file_registry_lock);
    owner->next = ube_file_readers; ube_file_readers = owner;
    ReleaseSRWLockExclusive(&ube_file_registry_lock);
    (void)InterlockedIncrement(&ube_file_test_handles);
    return owner->token;
}

static int checks;
#define CHECK(c) do { ++checks; if (!(c)) { fprintf(stderr,"output oracle line %d: %s\n",__LINE__,#c); return 1; } } while (0)
#ifdef LOST_OWNER_CONTROL
static int32_t lost_close(int32_t* token, int32_t* failure) {
    int32_t old=*token;
    int32_t result=ube_file_try_close(token,failure);
    if (result) *token=old;
    return result;
}
#define ube_file_try_close lost_close
#endif
static void observe(void) { allocations=0; copies=0; writes=0; flushes=0; observing=1; }
static int clean_cost(void) { observing=0; return allocations == 0 && copies == 0; }

static int contents(const wchar_t* path, const unsigned char* expected, DWORD length) {
    HANDLE file = CreateFileW(path,GENERIC_READ,FILE_SHARE_READ | FILE_SHARE_WRITE,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL);
    if (file == INVALID_HANDLE_VALUE) return 0;
    unsigned char bytes[65537]; DWORD count=0; LARGE_INTEGER size;
    int ok=GetFileSizeEx(file,&size) && size.QuadPart == length &&
        ReadFile(file,bytes,sizeof(bytes),&count,NULL) && count == length &&
        memcmp(bytes,expected,length) == 0;
    return CloseHandle(file) && ok;
}

static int cases(void) {
    void* source=NULL; struct ube_gc_root root={0};
    CHECK(ube_gc_root_enter(&root,&source));
    CHECK(ube_value_try_resize(&source,65536,&ube_file_byte_layout,0));
    struct ube_array* array=source;
    array->lower=-11; array->upper=65524;
    unsigned char expected[65536];
    for (size_t index=0; index<sizeof(expected); ++index) expected[index]=(unsigned char)index;
    memcpy(array->data,expected,sizeof(expected));
    int32_t token=create_output(L"exact.bin"), count=91, failure=92;
    CHECK(token>0); const int32_t original_token=token;
    for (int32_t seed=7; seed<=77; seed+=70) {
        ube_err_set(seed,"prior","output"); observe();
        CHECK(ube_file_try_write(token,&source,65536,0,&count,&failure));
        CHECK(clean_cost() && writes==0 && count==0 && failure==0 && ube_err_number()==seed);
        void* empty=NULL;
        CHECK(ube_file_try_write(token,&empty,0,0,&count,&failure) && count==0 && failure==0 && ube_err_number()==seed);
    }
    const int32_t invalid[][2]={{-1,1},{0,-1},{0,65537},{65537,0},{65536,1},{INT32_MAX,1},{1,INT32_MAX}};
    for (size_t i=0;i<sizeof(invalid)/sizeof(invalid[0]);++i) {
        observe(); CHECK(!ube_file_try_write(token,&source,invalid[i][0],invalid[i][1],&count,&failure));
        CHECK(clean_cost() && writes==0 && count==0 && failure==1 && ube_err_number()==5);
    }
    observe();
    CHECK(!ube_file_try_write(token,NULL,0,0,&count,&failure) && count==0 && failure==1);
    CHECK(!ube_file_try_write(token,&source,0,1,NULL,&failure) && failure==1);
    CHECK(!ube_file_try_write(token,&source,0,1,&count,NULL) && count==0);
    count=71; CHECK(!ube_file_try_write(token,&source,0,1,&count,&count) && count==71 && ube_err_number()==5);
    CHECK(!ube_file_try_flush(token,NULL));
    CHECK(!ube_file_try_write(-1,&source,0,1,&count,&failure) && failure==9 && count==0);
    CHECK(!ube_file_try_flush(-1,&failure) && failure==9);
    CHECK(clean_cost() && writes==0 && flushes==0);
    CHECK(ube_file_test_hold(token,1));
    CHECK(!ube_file_try_write(token,&source,0,1,&count,&failure) && failure==13 && count==0);
    CHECK(!ube_file_try_flush(token,&failure) && failure==13);
    CHECK(!ube_file_try_close(&token,&failure) && failure==13 && token==original_token);
    CHECK(ube_file_test_hold(token,0));
    ube_err_set(77,"prior","output"); observe();
    CHECK(ube_file_try_write(token,&source,0,65536,&count,&failure));
    CHECK(clean_cost() && writes==1 && count==65536 && failure==0 && ube_err_number()==77);
    CHECK(contents(L"exact.bin",expected,65536));
    CHECK(array->lower==-11 && array->upper==65524 && memcmp(array->data,expected,65536)==0);
    CHECK(ube_gc_header_from_value(source)->pin_count==0);
    observe(); CHECK(ube_file_try_flush(token,&failure));
    CHECK(clean_cost() && flushes==1 && failure==0 && ube_err_number()==77);
    flush_mode=1; CHECK(!ube_file_try_flush(token,&failure) && failure==16 && ube_err_number()==57); flush_mode=0;
    CHECK(ube_file_try_flush(token,&failure) && failure==0 && ube_err_number()==57);
    ube_file_test_inject(6);
    CHECK(!ube_file_try_close(&token,&failure) && failure==7 && token==original_token && ube_file_test_open_handles()==1);
    CHECK(ube_file_try_close(&token,&failure) && token==0 && ube_file_test_open_handles()==0);
    CHECK(!ube_file_try_write(original_token,&source,0,0,&count,&failure) && failure==9);
    CHECK(!ube_file_try_flush(original_token,&failure) && failure==9);
    CHECK(ube_file_try_close(&token,&failure) && token==0);

    token=create_output(L"short.bin"); CHECK(token>original_token);
    write_mode=1; observe();
    CHECK(ube_file_try_write(token,&source,3,14,&count,&failure) && count==7 && failure==0);
    CHECK(clean_cost() && writes==1 && contents(L"short.bin",expected+3,7));
    write_mode=0; CHECK(ube_file_try_write(token,&source,10,7,&count,&failure) && count==7);
    CHECK(contents(L"short.bin",expected+3,14));
    write_mode=2; CHECK(ube_file_try_write(token,&source,0,4,&count,&failure) && count==0 && failure==0);
    CHECK(contents(L"short.bin",expected+3,14));
    write_mode=3; CHECK(!ube_file_try_write(token,&source,0,4,&count,&failure) && count==0 && failure==15 && ube_err_number()==57);
    CHECK(contents(L"short.bin",expected+3,14));
    write_mode=0; CHECK(ube_file_try_close(&token,&failure));
    token=create_output(L"partial-failure.bin"); CHECK(token>0);
    write_mode=4; CHECK(!ube_file_try_write(token,&source,5,8,&count,&failure) && count==4 && failure==15 && ube_err_number()==57);
    CHECK(contents(L"partial-failure.bin",expected+5,4));
    CHECK(ube_gc_header_from_value(source)->pin_count==0 && memcmp(array->data,expected,65536)==0);
    write_mode=0; CHECK(ube_file_try_close(&token,&failure));

    /* A cooperative caller stops between operations and explicitly closes;
       no native call invents a cancellation scheduler or resumes the suffix. */
    token=create_output(L"cancelled.bin"); CHECK(token>0);
    int stop_requested=0; int32_t completed=0;
    while (!stop_requested && completed<8) {
        CHECK(ube_file_try_write(token,&source,completed,4,&count,&failure) && count==4);
        completed+=count; stop_requested=1;
    }
    CHECK(completed==4 && contents(L"cancelled.bin",expected,4));
    CHECK(ube_file_try_close(&token,&failure) && token==0);

    /* Read-only tokens are admitted through the real existing read API. */
    void* path=NULL; struct ube_gc_root path_root={0};
    CHECK(ube_gc_root_enter(&path_root,&path));
    CHECK(ube_value_try_resize(&path,9,&ube_file_byte_layout,0));
    memcpy(((struct ube_array*)path)->data,"exact.bin",9);
    int32_t length=0; CHECK(ube_file_try_open(&path,65536,&token,&length,&failure));
    observe(); CHECK(!ube_file_try_write(token,&source,0,0,&count,&failure) && failure==1);
    CHECK(!ube_file_try_flush(token,&failure) && failure==1);
    CHECK(clean_cost() && writes==0 && flushes==0);
    CHECK(ube_file_try_close(&token,&failure));
    CHECK(ube_gc_root_leave(&path_root));
    token=create_output(L"pressure.bin"); CHECK(token>0);
    unsigned char saved=expected[0];
    CHECK(!ube_file_try_read(token,&source,0,1,&count,&failure) && count==0 && failure==1 && array->data[0]==saved);
    /* Existing rooted data must remain usable with real root capacity full. */
    size_t available=UBE_GC_MAX_ROOTS-ube_gc_root_count;
    struct ube_gc_root* pressure=calloc(available,sizeof(*pressure)); void* neutral=NULL;
    CHECK(pressure!=NULL);
    for (size_t i=0;i<available;++i) CHECK(ube_gc_root_enter(&pressure[i],&neutral));
    ube_gc_test_fail_next_allocations(2); observe();
    CHECK(ube_file_try_write(token,&source,0,3,&count,&failure) && count==3);
    CHECK(ube_file_try_flush(token,&failure));
    CHECK(clean_cost() && writes==1 && flushes==1 && ube_gc_header_from_value(source)->pin_count==0);
    ube_gc_test_fail_next_allocations(0);
    for (size_t i=0;i<available;++i) CHECK(ube_gc_root_leave(&pressure[i]));
    free(pressure); CHECK(contents(L"pressure.bin",expected,3));
    CHECK(ube_file_try_close(&token,&failure));
    CHECK(ube_gc_root_leave(&root)); source=NULL; path=NULL; (void)ube_gc_collect();
    CHECK(ube_file_test_open_handles()==0 && ube_gc_live_allocation_bytes()==0 && ube_gc_root_count==0);
    return 0;
}

struct work { void* source; int32_t token; HANDLE ready, release; int result; };
static DWORD WINAPI worker(void* argument) {
    struct work* work=argument;
    reached=work->ready; release_write=work->release;
    int32_t count=0,failure=0;
    ube_err_set(work->token,"thread","output"); observe();
    int ok=ube_file_try_write(work->token,&work->source,0,4,&count,&failure);
    work->result=ok && count==4 && failure==0 && ube_err_number()==work->token && clean_cost() && writes==1;
    return work->result ? 0 : 1;
}

static int concurrency(void) {
    void* source=NULL; struct ube_gc_root root={0};
    CHECK(ube_gc_root_enter(&root,&source) && ube_value_try_resize(&source,4,&ube_file_byte_layout,0));
    const unsigned char expected[]={0,13,10,255}; memcpy(((struct ube_array*)source)->data,expected,4);
    struct work work[4]={{0}}; HANDLE threads[4]={0};
    const wchar_t* paths[]={L"worker0.bin",L"worker1.bin",L"worker2.bin",L"worker3.bin"};
    HANDLE release=CreateEventW(NULL,TRUE,FALSE,NULL); CHECK(release!=NULL);
    for (int i=0;i<4;++i) {
        work[i].source=source; work[i].token=create_output(paths[i]); work[i].release=release;
        work[i].ready=CreateEventW(NULL,TRUE,FALSE,NULL); CHECK(work[i].token>0 && work[i].ready!=NULL);
        threads[i]=CreateThread(NULL,0,worker,&work[i],0,NULL); CHECK(threads[i]!=NULL);
    }
    for (int i=0;i<4;++i) CHECK(WaitForSingleObject(work[i].ready,5000)==WAIT_OBJECT_0);
    CHECK(ube_gc_header_from_value(source)->pin_count==4);
    int32_t count=0,failure=0;
    CHECK(!ube_file_try_write(work[0].token,&source,0,4,&count,&failure) && failure==13);
    CHECK(!ube_file_try_flush(work[0].token,&failure) && failure==13);
    CHECK(!ube_file_try_close(&work[0].token,&failure) && failure==13 && work[0].token>0);
    CHECK(SetEvent(release));
    for (int i=0;i<4;++i) {
        CHECK(WaitForSingleObject(threads[i],5000)==WAIT_OBJECT_0 && work[i].result);
        CHECK(CloseHandle(threads[i]) && CloseHandle(work[i].ready));
        CHECK(ube_file_try_close(&work[i].token,&failure));
        CHECK(contents(paths[i],expected,4));
    }
    CHECK(CloseHandle(release));
    CHECK(ube_gc_header_from_value(source)->pin_count==0 && memcmp(((struct ube_array*)source)->data,expected,4)==0);
    CHECK(ube_gc_root_leave(&root)); source=NULL; (void)ube_gc_collect();
    CHECK(ube_file_test_open_handles()==0 && ube_gc_live_allocation_bytes()==0 && ube_gc_root_count==0);
    return 0;
}

int main(void) {
    if (cases() || concurrency()) return 1;
    printf("PASS counted file output %d assertions\n",checks);
    return 0;
}
