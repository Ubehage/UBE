/* Included after file_primitives.c. Owns only native counted output over an
   admitted token. UBE owns chunking, progress and cancellation between calls.
   Contract: ../../../std-lib/FILE-OUTPUT-CONTRACT.md. */
#ifndef UBE_FILE_WRITE
#define UBE_FILE_WRITE WriteFile
#endif
#ifndef UBE_FILE_FLUSH
#define UBE_FILE_FLUSH FlushFileBuffers
#endif

int32_t ube_file_try_write(int32_t token, void* const* source, int32_t start,
        int32_t count, int32_t* written_count, int32_t* failure) {
    if (written_count != NULL && written_count == failure) {
        ube_err_set(5,"aliased file write outputs","UBECore.FileBytes");
        return 0;
    }
    if (written_count != NULL) *written_count = 0;
    if (failure != NULL) *failure = 0;
    if (written_count == NULL || failure == NULL || start < 0 || count < 0 || count > UBE_FILE_CHUNK)
        return ube_file_fail(failure,1);
    int32_t length = 0;
    struct ube_array* bytes = ube_file_borrow(source,&length);
    const int neutral = source != NULL && __atomic_load_n(source,__ATOMIC_SEQ_CST) == NULL;
    if ((bytes == NULL && !(count == 0 && neutral)) || start > length || count > length - start) {
        if (bytes != NULL) (void)ube_gc_unpin(bytes);
        return ube_file_fail(failure,1);
    }
    struct ube_file_reader* file = ube_file_acquire(token,failure);
    if (file == NULL) { if (bytes != NULL) (void)ube_gc_unpin(bytes); return 0; }
    if (!file->writable) {
        ube_file_release(file);
        if (bytes != NULL) (void)ube_gc_unpin(bytes);
        return ube_file_fail(failure,1);
    }
    DWORD written = 0;
    const int success = count == 0 ||
        UBE_FILE_WRITE(file->handle,bytes->data + (size_t)start,(DWORD)count,&written,NULL) != 0;
    /* Reject an invalid native count rather than permit a caller to skip bytes.
       A failed write can have affected the file; this is never rollback. */
    const int valid_count = written <= (DWORD)count;
    if (valid_count) *written_count = (int32_t)written;
    ube_file_release(file);
    if (bytes != NULL) (void)ube_gc_unpin(bytes);
    return success && valid_count ? 1 : ube_file_fail(failure,15);
}

int32_t ube_file_try_flush(int32_t token, int32_t* failure) {
    if (failure == NULL) return ube_file_fail(NULL,1);
    *failure = 0;
    struct ube_file_reader* file = ube_file_acquire(token,failure);
    if (file == NULL) return 0;
    if (!file->writable) { ube_file_release(file); return ube_file_fail(failure,1); }
    const int success = UBE_FILE_FLUSH(file->handle) != 0;
    ube_file_release(file);
    return success ? 1 : ube_file_fail(failure,16);
}
