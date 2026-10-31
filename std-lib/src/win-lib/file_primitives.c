/* Included by bootstrap_runtime.c after typed storage support. This temporary
   adapter owns OS entry, safe tokens and rooted native access only. Contract:
   ../../FILE-BYTES-CONTRACT.md. Never put a whole-file loop here. */
#define UBE_FILE_CHUNK 65536
struct ube_file_reader {
    struct ube_file_reader* next;
    HANDLE handle;
    unsigned char* scratch;
    int32_t token;
    int busy;
};
static SRWLOCK ube_file_registry_lock = SRWLOCK_INIT;
static struct ube_file_reader* ube_file_readers;
static int32_t ube_file_last_token;
static const struct ube_value_layout ube_file_byte_layout = {1,0,0,NULL,0,NULL};

#ifdef UBE_FILE_TESTING
static volatile LONG ube_file_test_handles;
static volatile LONG ube_file_test_payload_allocations;
static volatile LONG ube_file_test_read_calls;
static int64_t ube_file_test_read_bytes;
static int64_t ube_file_test_published_bytes;
static int32_t ube_file_test_mode(void) {
    struct ube_thread_local_state* state = ube_tls_get(0);
    return state == NULL ? 0 : state->file_test_mode;
}
void ube_file_test_inject(int32_t mode) {
    struct ube_thread_local_state* state = ube_tls_get(1);
    if (state != NULL) state->file_test_mode = mode;
}
void ube_file_test_before_read(void (*callback)(void*), void* context) {
    struct ube_thread_local_state* state = ube_tls_get(1);
    if (state != NULL) {
        state->file_before_read = callback;
        state->file_before_read_context = context;
    }
}
int32_t ube_file_test_open_handles(void) { return InterlockedCompareExchange(&ube_file_test_handles,0,0); }
int32_t ube_file_test_payloads(void) { return InterlockedCompareExchange(&ube_file_test_payload_allocations,0,0); }
int32_t ube_file_test_reads(void) { return InterlockedCompareExchange(&ube_file_test_read_calls,0,0); }
int64_t ube_file_test_bytes_read(void) { return __atomic_load_n(&ube_file_test_read_bytes,__ATOMIC_SEQ_CST); }
int64_t ube_file_test_bytes_published(void) { return __atomic_load_n(&ube_file_test_published_bytes,__ATOMIC_SEQ_CST); }
int32_t ube_file_test_hold(int32_t token, int32_t held) {
    AcquireSRWLockExclusive(&ube_file_registry_lock);
    struct ube_file_reader* reader = ube_file_readers;
    while (reader != NULL && reader->token != token) reader = reader->next;
    if (reader != NULL) reader->busy = held != 0;
    ReleaseSRWLockExclusive(&ube_file_registry_lock);
    return reader != NULL;
}
#define UBE_FILE_OBSERVE(counter) ((void)InterlockedIncrement(&ube_file_test_##counter))
#else
#define UBE_FILE_OBSERVE(counter) ((void)0)
#endif

static int32_t ube_file_fail(int32_t* failure, int32_t kind) {
    if (failure != NULL) *failure = kind;
    int32_t number = 5;
    if (kind == 8) number = 7;
    else if (kind == 4) number = 6;
    else if (kind == 3 || kind == 5 || kind == 6 || kind == 7 || kind == 11) number = 57;
    ube_err_set(number,"byte-file operation failed","UBECore.FileBytes");
    return 0;
}

int32_t ube_error_set_number(int32_t number) {
    ube_err_set(number > 0 ? number : 5,"explicit recoverable error","UBECore");
    return 0;
}

/* Pin a checked live Byte array while native code uses its payload. No GC lock
   is held during an OS call. The caller still owns coherent mutable access. */
static struct ube_array* ube_file_borrow(void* const* holder, int32_t* length) {
    *length = 0;
    if (holder == NULL) return NULL;
    ube_gc_enter_lock();
    struct ube_array* value = __atomic_load_n((struct ube_array* const*)holder,__ATOMIC_SEQ_CST);
    struct ube_gc_header* header = value == NULL ? NULL : ube_gc_header_from_value(value);
    if (header == NULL || header->payload_size < sizeof(*value) || value->element_size != 1) {
        ube_gc_leave_lock();
        return NULL;
    }
    const int64_t count = (int64_t)value->upper - value->lower + 1;
    if (count < 0 || count > INT32_MAX || (uint64_t)count > header->payload_size - sizeof(*value) || !ube_gc_pin(value)) {
        ube_gc_leave_lock();
        return NULL;
    }
    *length = (int32_t)count;
    ube_gc_leave_lock();
    return value;
}

static struct ube_file_reader* ube_file_acquire(int32_t token, int32_t* failure) {
    AcquireSRWLockExclusive(&ube_file_registry_lock);
    struct ube_file_reader* reader = ube_file_readers;
    while (reader != NULL && reader->token != token) reader = reader->next;
    if (reader == NULL || reader->busy) {
        const int32_t kind = reader == NULL ? 9 : 13;
        ReleaseSRWLockExclusive(&ube_file_registry_lock);
        ube_file_fail(failure,kind);
        return NULL;
    }
    reader->busy = 1;
    ReleaseSRWLockExclusive(&ube_file_registry_lock);
    return reader;
}

static void ube_file_release(struct ube_file_reader* reader) {
    AcquireSRWLockExclusive(&ube_file_registry_lock);
    reader->busy = 0;
    ReleaseSRWLockExclusive(&ube_file_registry_lock);
}

/* Reserve metadata/token before opening. Even failure to close a rejected
   file can then return an explicit live owner without allocating in cleanup. */
static int32_t ube_file_reject_open(struct ube_file_reader* reader,
        int32_t* token, int32_t* failure, int32_t kind) {
    int closed;
#ifdef UBE_FILE_TESTING
    if (ube_file_test_mode() == 7) { ube_file_test_inject(0); closed = 0; }
    else
#endif
    closed = CloseHandle(reader->handle) != 0;
    if (!closed) {
        AcquireSRWLockExclusive(&ube_file_registry_lock);
        reader->next = ube_file_readers;
        ube_file_readers = reader;
        *token = reader->token;
        ReleaseSRWLockExclusive(&ube_file_registry_lock);
        return ube_file_fail(failure,7);
    }
#ifdef UBE_FILE_TESTING
    (void)InterlockedDecrement(&ube_file_test_handles);
#endif
    free(reader->scratch);
    free(reader);
    return ube_file_fail(failure,kind);
}

int32_t ube_file_try_open(void* const* path, int32_t limit, int32_t* token,
        int32_t* length, int32_t* failure) {
    if (token != NULL && (token == length || token == failure)) {
        ube_err_set(5,"aliased file outputs","UBECore.FileBytes");
        return 0;
    }
    if (length != NULL) *length = 0;
    if (failure != NULL) *failure = 0;
    if (token == NULL || length == NULL || failure == NULL || token == length || token == failure || length == failure || *token != 0 || limit < 0)
        return ube_file_fail(failure,1);
    int32_t path_length = 0;
    struct ube_array* bytes = ube_file_borrow(path,&path_length);
    if (bytes == NULL || path_length == 0) {
        if (bytes != NULL) (void)ube_gc_unpin(bytes);
        return ube_file_fail(failure,2);
    }
    const int wide_count = path_length > 131068 || memchr(bytes->data,0,(size_t)path_length) != NULL ? 0 :
        MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,(const char*)bytes->data,path_length,NULL,0);
    if (wide_count <= 0 || wide_count > 32767) {
        (void)ube_gc_unpin(bytes);
        return ube_file_fail(failure,2);
    }
    wchar_t* wide = malloc(((size_t)wide_count + 1) * sizeof(*wide));
    if (wide == NULL) { (void)ube_gc_unpin(bytes); return ube_file_fail(failure,8); }
    const int converted = MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,(const char*)bytes->data,path_length,wide,wide_count);
    (void)ube_gc_unpin(bytes);
    if (converted != wide_count) { free(wide); return ube_file_fail(failure,2); }
    wide[wide_count] = 0;
    struct ube_file_reader* reader = calloc(1,sizeof(*reader));
    if (reader == NULL) { free(wide); return ube_file_fail(failure,8); }
    AcquireSRWLockExclusive(&ube_file_registry_lock);
    if (ube_file_last_token == INT32_MAX) {
        ReleaseSRWLockExclusive(&ube_file_registry_lock);
        free(reader); free(wide);
        return ube_file_fail(failure,8);
    }
    reader->token = ++ube_file_last_token;
    ReleaseSRWLockExclusive(&ube_file_registry_lock);
    HANDLE native = CreateFileW(wide,GENERIC_READ,FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL);
    free(wide);
    if (native == INVALID_HANDLE_VALUE) { free(reader); return ube_file_fail(failure,3); }
    reader->handle = native;
    UBE_FILE_OBSERVE(handles);
    LARGE_INTEGER size;
    const int invalid = GetFileType(native) != FILE_TYPE_DISK || !GetFileSizeEx(native,&size) || size.QuadPart < 0;
    if (invalid || size.QuadPart > limit) {
        const int32_t kind = invalid ? 3 : 4;
        return ube_file_reject_open(reader,token,failure,kind);
    }
    unsigned char* scratch = NULL;
#ifdef UBE_FILE_TESTING
    if (ube_file_test_mode() == 1) ube_file_test_inject(0);
    else
#endif
    scratch = malloc(UBE_FILE_CHUNK);
    if (scratch != NULL) UBE_FILE_OBSERVE(payload_allocations);
    if (scratch == NULL) return ube_file_reject_open(reader,token,failure,8);
    reader->scratch = scratch;
    AcquireSRWLockExclusive(&ube_file_registry_lock);
    reader->next = ube_file_readers;
    ube_file_readers = reader;
    *token = reader->token;
    *length = (int32_t)size.QuadPart;
    ReleaseSRWLockExclusive(&ube_file_registry_lock);
    return 1;
}

int32_t ube_file_try_read(int32_t token, void* const* destination, int32_t start,
        int32_t count, int32_t* read_count, int32_t* failure) {
    if (read_count != NULL) *read_count = 0;
    if (failure != NULL) *failure = 0;
    if (read_count == NULL || failure == NULL || read_count == failure || count < 0 || count > UBE_FILE_CHUNK || start < 0)
        return ube_file_fail(failure,1);
    int32_t length = 0;
    struct ube_array* bytes = ube_file_borrow(destination,&length);
    const int neutral = destination != NULL && __atomic_load_n(destination,__ATOMIC_SEQ_CST) == NULL;
    if ((bytes == NULL && !(count == 0 && neutral)) || start > length || count > length - start) {
        if (bytes != NULL) (void)ube_gc_unpin(bytes);
        return ube_file_fail(failure,1);
    }
    struct ube_file_reader* reader = ube_file_acquire(token,failure);
    if (reader == NULL) { if (bytes != NULL) (void)ube_gc_unpin(bytes); return 0; }
    if (reader->scratch == NULL) {
        ube_file_release(reader);
        if (bytes != NULL) (void)ube_gc_unpin(bytes);
        return ube_file_fail(failure,1);
    }
    DWORD obtained = 0;
    DWORD requested = (DWORD)count;
    int success;
#ifdef UBE_FILE_TESTING
    struct ube_thread_local_state* state = ube_tls_get(0);
    if (state != NULL && state->file_before_read != NULL) {
        void (*callback)(void*) = state->file_before_read;
        void* context = state->file_before_read_context;
        state->file_before_read = NULL;
        state->file_before_read_context = NULL;
        callback(context);
    }
    if (ube_file_test_mode() == 2) { ube_file_test_inject(0); success = 0; }
    else if (ube_file_test_mode() == 3) { ube_file_test_inject(0); success = 1; }
    else {
        if (ube_file_test_mode() == 4 && requested > 1) requested /= 2;
#endif
        UBE_FILE_OBSERVE(read_calls);
        success = ReadFile(reader->handle,reader->scratch,requested,&obtained,NULL) != 0;
#ifdef UBE_FILE_TESTING
        (void)__atomic_add_fetch(&ube_file_test_read_bytes,(int64_t)obtained,__ATOMIC_SEQ_CST);
    }
#endif
    if (success) {
        for (DWORD index = 0; index < obtained; ++index) {
            __atomic_store_n(bytes->data + (size_t)start + index,reader->scratch[index],__ATOMIC_SEQ_CST);
            UBE_VALUE_OBSERVE_COPY(1);
        }
#ifdef UBE_FILE_TESTING
        (void)__atomic_add_fetch(&ube_file_test_published_bytes,(int64_t)obtained,__ATOMIC_SEQ_CST);
#endif
        *read_count = (int32_t)obtained;
    }
    ube_file_release(reader);
    if (bytes != NULL) (void)ube_gc_unpin(bytes);
    return success ? 1 : ube_file_fail(failure,5);
}

int32_t ube_file_try_close(int32_t* token, int32_t* failure) {
    if (token != NULL && token == failure) {
        ube_err_set(5,"aliased file close outputs","UBECore.FileBytes");
        return 0;
    }
    if (failure != NULL) *failure = 0;
    if (token == NULL || failure == NULL || token == failure) return ube_file_fail(failure,1);
    if (*token == 0) return 1;
    struct ube_file_reader* reader = ube_file_acquire(*token,failure);
    if (reader == NULL) return 0;
#ifdef UBE_FILE_TESTING
    if (ube_file_test_mode() == 6) { ube_file_test_inject(0); ube_file_release(reader); return ube_file_fail(failure,7); }
#endif
    if (!CloseHandle(reader->handle)) { ube_file_release(reader); return ube_file_fail(failure,7); }
    AcquireSRWLockExclusive(&ube_file_registry_lock);
    struct ube_file_reader** link = &ube_file_readers;
    while (*link != reader) link = &(*link)->next;
    *link = reader->next;
    *token = 0;
    ReleaseSRWLockExclusive(&ube_file_registry_lock);
    free(reader->scratch); free(reader);
#ifdef UBE_FILE_TESTING
    (void)InterlockedDecrement(&ube_file_test_handles);
    if (ube_file_test_mode() == 5) { ube_file_test_inject(0); return ube_file_fail(failure,7); }
#endif
    return 1;
}

int32_t ube_process_try_argument(int32_t index, void** result, int32_t* failure) {
    if (failure != NULL) *failure = 0;
    if (result == NULL || failure == NULL || index < 0 || index == INT32_MAX) return ube_file_fail(failure,1);
    HMODULE shell = LoadLibraryExW(L"shell32.dll",NULL,LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (shell == NULL) return ube_file_fail(failure,3);
    typedef LPWSTR* (WINAPI *ube_split_arguments)(LPCWSTR,int*);
    ube_split_arguments split = NULL;
    FARPROC address = GetProcAddress(shell,"CommandLineToArgvW");
    _Static_assert(sizeof(split) == sizeof(address),"Windows function pointer size");
    memcpy(&split,&address,sizeof(split));
    int argc = 0;
    LPWSTR* argv = split == NULL ? NULL : split(GetCommandLineW(),&argc);
    if (argv == NULL || index >= argc - 1) {
        if (argv != NULL) (void)LocalFree(argv);
        (void)FreeLibrary(shell);
        return ube_file_fail(failure,argv == NULL ? 8 : 12);
    }
    const int needed = WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,argv[index + 1],-1,NULL,0,NULL,NULL);
    void* prepared = NULL;
    struct ube_gc_root root = {0};
    int32_t kind = needed <= 0 ? 2 : 8;
    int success = needed > 0 && ube_gc_root_enter(&root,&prepared) &&
        ube_value_try_resize(&prepared,needed - 1,&ube_file_byte_layout,0);
    if (success && needed > 1) {
        /* Conversion's terminator is kept in native temporary storage; the
           resulting managed array has exactly the counted argument bytes. */
        char* encoded = malloc((size_t)needed);
        if (encoded == NULL) success = 0;
        else {
            if (WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,argv[index + 1],-1,encoded,needed,NULL,NULL) != needed) {
                success = 0; kind = 2;
            } else {
                ube_gc_enter_lock();
                memcpy(((struct ube_array*)prepared)->data,encoded,(size_t)needed - 1);
                UBE_VALUE_OBSERVE_COPY((size_t)needed - 1);
                ube_gc_leave_lock();
            }
            free(encoded);
        }
    }
    if (success) {
        ube_gc_enter_lock();
        __atomic_store_n(result,prepared,__ATOMIC_SEQ_CST);
        (void)ube_gc_root_leave(&root);
        ube_gc_leave_lock();
    } else (void)ube_gc_root_leave(&root);
    (void)LocalFree(argv);
    (void)FreeLibrary(shell);
    return success ? 1 : ube_file_fail(failure,kind);
}
