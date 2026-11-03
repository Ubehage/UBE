#include <windows.h>
#include <stdio.h>

typedef void *(*ContextCreateFn)(void);
typedef void (*DisposeFn)(void *);
typedef int (*BufferFromFileFn)(const char *, void **, char **);
typedef int (*ParseFn)(void *, void *, void **, char **);
typedef int (*VerifyFn)(void *, int, char **);

int wmain(int argc, wchar_t **argv) {
    if (argc != 3) { fprintf(stderr, "usage: api-probe <LLVM-C.dll> <ASCII IR path>\n"); return 3; }
    HMODULE dll = LoadLibraryW(argv[1]);
    if (!dll) { fprintf(stderr, "library load failure\n"); return 3; }
    ContextCreateFn context_create = (ContextCreateFn)GetProcAddress(dll, "LLVMContextCreate");
    DisposeFn context_dispose = (DisposeFn)GetProcAddress(dll, "LLVMContextDispose");
    DisposeFn module_dispose = (DisposeFn)GetProcAddress(dll, "LLVMDisposeModule");
    DisposeFn message_dispose = (DisposeFn)GetProcAddress(dll, "LLVMDisposeMessage");
    BufferFromFileFn buffer_from_file = (BufferFromFileFn)GetProcAddress(dll, "LLVMCreateMemoryBufferWithContentsOfFile");
    ParseFn parse = (ParseFn)GetProcAddress(dll, "LLVMParseIRInContext");
    VerifyFn verify = (VerifyFn)GetProcAddress(dll, "LLVMVerifyModule");
    if (!context_create || !context_dispose || !module_dispose || !message_dispose || !buffer_from_file || !parse || !verify) {
        fprintf(stderr, "missing library function\n"); FreeLibrary(dll); return 3;
    }
    char path[32768];
    if (!WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, argv[2], -1, path, sizeof(path), NULL, NULL)) {
        FreeLibrary(dll); return 3;
    }
    void *context = context_create(), *buffer = NULL, *module = NULL;
    char *message = NULL;
    if (!context) { FreeLibrary(dll); return 3; }
    int result = 3;
    if (buffer_from_file(path, &buffer, &message)) { puts("input failure"); goto cleanup; }
    if (parse(context, buffer, &module, &message)) { puts("parse failure"); result = 2; goto cleanup; }
    if (verify(module, 2, &message)) { puts("invalid module"); result = 1; goto cleanup; }
    puts("valid module"); result = 0;
cleanup:
    if (message) message_dispose(message);
    if (module) module_dispose(module);
    context_dispose(context); FreeLibrary(dll);
    return result;
}
