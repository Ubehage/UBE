#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef int32_t (*add_values_fn)(int32_t left, int32_t right, int32_t* result);
typedef int32_t (*copy_diagnostic_fn)(char* buffer, uint64_t capacity,
                                     uint64_t* required);
typedef int32_t (*shutdown_fn)(void);
typedef int32_t (*create_lease_fn)(uint64_t* result);
typedef int32_t (*copy_handle_fn)(uint64_t handle, uint64_t* copied);
typedef int32_t (*release_handle_fn)(uint64_t handle);

static const void* data_symbol(HMODULE library, const char* name) {
    FARPROC procedure = GetProcAddress(library, name);
    const void* result = NULL;
    _Static_assert(sizeof(result) == sizeof(procedure), "Windows symbol pointer size mismatch");
    memcpy(&result, &procedure, sizeof(result));
    return result;
}

int main(int argc, char** argv) {
    if (argc != 2) return 10;
    HMODULE library = LoadLibraryA(argv[1]);
    if (library == NULL) return 11;
    const int32_t* major = data_symbol(library, "ube_library_abi_major");
    const int32_t* pointer_bits = data_symbol(library, "ube_library_pointer_bits");
    const int32_t* export_count = data_symbol(library, "ube_library_export_count");
    const uint64_t* signature_hashes = data_symbol(
        library, "ube_library_export_signature_hashes");
    add_values_fn add_values = (add_values_fn)(uintptr_t)GetProcAddress(
        library, "ube_export_41646456616C756573");
    copy_diagnostic_fn copy_diagnostic = (copy_diagnostic_fn)(uintptr_t)GetProcAddress(
        library, "ube_library_copy_diagnostic");
    shutdown_fn shutdown_library = (shutdown_fn)(uintptr_t)GetProcAddress(
        library, "ube_library_shutdown");
    create_lease_fn create_lease = (create_lease_fn)(uintptr_t)GetProcAddress(
        library, "ube_export_4372656174654C656173656456616C7565");
    copy_handle_fn copy_handle = (copy_handle_fn)(uintptr_t)GetProcAddress(
        library, "ube_library_copy_handle");
    release_handle_fn release_handle = (release_handle_fn)(uintptr_t)GetProcAddress(
        library, "ube_library_release_handle");
    if (major == NULL || *major != 1 || pointer_bits == NULL || *pointer_bits != 64 ||
        export_count == NULL || *export_count != 2 || signature_hashes == NULL ||
        signature_hashes[0] == 0 || signature_hashes[1] == 0 ||
        signature_hashes[0] == signature_hashes[1] ||
        add_values == NULL || copy_diagnostic == NULL || shutdown_library == NULL ||
        create_lease == NULL || copy_handle == NULL || release_handle == NULL) {
        FreeLibrary(library);
        return 12;
    }
    int32_t result = 0;
    if (add_values(19, 23, &result) != 0 || result != 42) {
        FreeLibrary(library);
        return 13;
    }
    if (add_values(1, 2, NULL) != 1) {
        FreeLibrary(library);
        return 14;
    }
    uint64_t required = 0;
    char diagnostic[64];
    if (copy_diagnostic(NULL, 0, &required) != 0 || required > sizeof(diagnostic) ||
        copy_diagnostic(diagnostic, sizeof(diagnostic), &required) != 0 ||
        strstr(diagnostic, "result pointer") == NULL) {
        FreeLibrary(library);
        return 15;
    }
    uint64_t first_handle = 0;
    uint64_t second_handle = 0;
    uint64_t third_handle = 0;
    if (create_lease(&first_handle) != 0 || first_handle == 0 ||
        copy_handle(first_handle, &second_handle) != 0 || second_handle == 0 ||
        second_handle == first_handle) {
        FreeLibrary(library);
        return 16;
    }
    if (release_handle(first_handle) != 0 || release_handle(first_handle) != 0 ||
        copy_handle(first_handle, &third_handle) != 2 || third_handle != 0 ||
        copy_handle(second_handle, &third_handle) != 0 || third_handle == 0 ||
        release_handle(second_handle) != 0 || release_handle(third_handle) != 0) {
        FreeLibrary(library);
        return 17;
    }
    if (shutdown_library() != 0 || shutdown_library() != 0) {
        FreeLibrary(library);
        return 18;
    }
    if (add_values(1, 2, &result) != 3) {
        FreeLibrary(library);
        return 19;
    }
    if (!FreeLibrary(library)) return 20;
    puts("foreign ABI probe passed");
    return 0;
}
