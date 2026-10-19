#include <inttypes.h>
#include <limits.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct ube_allocation {
    struct ube_allocation* next;
    char data[];
};

struct ube_array {
    int32_t lower;
    int32_t upper;
    size_t element_size;
    unsigned char data[];
};

static struct ube_allocation* ube_allocations;
static int ube_cleanup_registered;
static int ube_argument_count;
static char** ube_arguments;

static void ube_release_allocations(void) {
    while (ube_allocations != NULL) {
        struct ube_allocation* allocation = ube_allocations;
        ube_allocations = allocation->next;
        free(allocation);
    }
}

static char* ube_allocate_string(size_t length) {
    if (!ube_cleanup_registered) {
        if (atexit(ube_release_allocations) != 0) {
            fputs("UBE runtime: could not register allocation cleanup\n", stderr);
            exit(70);
        }
        ube_cleanup_registered = 1;
    }
    if (length > SIZE_MAX - sizeof(struct ube_allocation) - 1) {
        fputs("UBE runtime: string size overflow\n", stderr);
        exit(70);
    }
    struct ube_allocation* allocation = malloc(sizeof(*allocation) + length + 1);
    if (allocation == NULL) {
        fputs("UBE runtime: out of memory while allocating a string\n", stderr);
        exit(70);
    }
    allocation->next = ube_allocations;
    ube_allocations = allocation;
    return allocation->data;
}

static void* ube_allocate_managed(size_t size) {
    if (!ube_cleanup_registered) {
        if (atexit(ube_release_allocations) != 0) {
            fputs("UBE runtime: could not register allocation cleanup\n", stderr);
            exit(70);
        }
        ube_cleanup_registered = 1;
    }
    if (size > SIZE_MAX - sizeof(struct ube_allocation)) {
        fputs("UBE runtime: allocation size overflow\n", stderr);
        exit(70);
    }
    struct ube_allocation* allocation = calloc(1, sizeof(*allocation) + size);
    if (allocation == NULL) {
        fputs("UBE runtime: out of memory\n", stderr);
        exit(70);
    }
    allocation->next = ube_allocations;
    ube_allocations = allocation;
    return allocation->data;
}

static void ube_release_managed(void* value) {
    if (value == NULL) return;
    struct ube_allocation** link = &ube_allocations;
    while (*link != NULL) {
        struct ube_allocation* allocation = *link;
        if ((void*)allocation->data == value) {
            *link = allocation->next;
            free(allocation);
            return;
        }
        link = &allocation->next;
    }
}

void ube_array_release(void* value) {
    ube_release_managed(value);
}

void* ube_array_redim(void* old_value, int32_t lower, int32_t upper,
                      size_t element_size, int preserve) {
    if (upper < lower || element_size == 0) {
        fputs("UBE runtime: invalid dynamic array bounds\n", stderr);
        exit(65);
    }
    const uint64_t count = (uint64_t)((int64_t)upper - (int64_t)lower + 1);
    if (count > (SIZE_MAX - sizeof(struct ube_array)) / element_size) {
        fputs("UBE runtime: dynamic array size overflow\n", stderr);
        exit(70);
    }
    struct ube_array* result = ube_allocate_managed(
        sizeof(*result) + (size_t)count * element_size);
    result->lower = lower;
    result->upper = upper;
    result->element_size = element_size;
    if (preserve && old_value != NULL) {
        const struct ube_array* old = old_value;
        if (old->element_size != element_size) {
            fputs("UBE runtime: ReDim Preserve element type mismatch\n", stderr);
            exit(70);
        }
        const int32_t copy_lower = lower > old->lower ? lower : old->lower;
        const int32_t copy_upper = upper < old->upper ? upper : old->upper;
        if (copy_lower <= copy_upper) {
            const size_t copy_count = (size_t)((int64_t)copy_upper - copy_lower + 1);
            memcpy(result->data + (size_t)(copy_lower - lower) * element_size,
                   old->data + (size_t)(copy_lower - old->lower) * element_size,
                   copy_count * element_size);
        }
    }
    ube_release_managed(old_value);
    return result;
}

void* ube_array_element(void* value, int32_t index) {
    if (value == NULL) {
        fputs("UBE runtime: dynamic array has not been dimensioned\n", stderr);
        exit(65);
    }
    struct ube_array* array = value;
    if (index < array->lower || index > array->upper) {
        fprintf(stderr, "UBE runtime: array index out of range: %" PRId32 "\n", index);
        exit(65);
    }
    return array->data + (size_t)(index - array->lower) * array->element_size;
}

int32_t ube_array_lbound(const void* value) {
    if (value == NULL) {
        fputs("UBE runtime: dynamic array has not been dimensioned\n", stderr);
        exit(65);
    }
    return ((const struct ube_array*)value)->lower;
}

int32_t ube_array_ubound(const void* value) {
    if (value == NULL) {
        fputs("UBE runtime: dynamic array has not been dimensioned\n", stderr);
        exit(65);
    }
    return ((const struct ube_array*)value)->upper;
}

char* ube_string_array_join(void** value_reference, int32_t count) {
    if (count < 0) {
        fputs("UBE runtime: string join count cannot be negative\n", stderr);
        exit(65);
    }
    if (count == 0) {
        char* empty = ube_allocate_string(0);
        empty[0] = '\0';
        return empty;
    }
    if (value_reference == NULL || *value_reference == NULL) {
        fputs("UBE runtime: string join array has not been dimensioned\n", stderr);
        exit(65);
    }

    const struct ube_array* array = *value_reference;
    const int64_t available = (int64_t)array->upper - array->lower + 1;
    if (array->element_size != sizeof(char*) || available < count) {
        fputs("UBE runtime: string join count exceeds the array bounds\n", stderr);
        exit(65);
    }

    const char* const* values = (const char* const*)array->data;
    size_t total = 0;
    for (int32_t index = 0; index < count; ++index) {
        const size_t length = values[index] != NULL ? strlen(values[index]) : 0;
        if (length > SIZE_MAX - total) {
            fputs("UBE runtime: joined string size overflow\n", stderr);
            exit(70);
        }
        total += length;
    }

    char* result = ube_allocate_string(total);
    size_t offset = 0;
    for (int32_t index = 0; index < count; ++index) {
        const char* value = values[index] != NULL ? values[index] : "";
        const size_t length = strlen(value);
        memcpy(result + offset, value, length);
        offset += length;
    }
    result[offset] = '\0';
    return result;
}

void ube_print_i32(int32_t value) {
    printf("%" PRId32, value);
}

void ube_print_i64(int64_t value) {
    printf("%" PRId64, value);
}

void ube_print_f64(double value) {
    printf("%.17g", value);
}

void ube_print_string(const char* value) {
    fputs(value != NULL ? value : "", stdout);
}

void ube_print_newline(void) {
    fputc('\n', stdout);
    fflush(stdout);
}

void ube_invalid_for_step(void) {
    fputs("UBE runtime: For Step cannot be zero\n", stderr);
    exit(65);
}

static void ube_integer_error(const char* operation) {
    fprintf(stderr, "UBE runtime: Long %s failed\n", operation);
    exit(65);
}

int32_t ube_checked_add_i32(int32_t left, int32_t right) {
    const int64_t result = (int64_t)left + right;
    if (result < INT32_MIN || result > INT32_MAX) ube_integer_error("addition overflow");
    return (int32_t)result;
}

int32_t ube_checked_sub_i32(int32_t left, int32_t right) {
    const int64_t result = (int64_t)left - right;
    if (result < INT32_MIN || result > INT32_MAX) ube_integer_error("subtraction overflow");
    return (int32_t)result;
}

int32_t ube_checked_mul_i32(int32_t left, int32_t right) {
    const int64_t result = (int64_t)left * right;
    if (result < INT32_MIN || result > INT32_MAX) ube_integer_error("multiplication overflow");
    return (int32_t)result;
}

int32_t ube_checked_div_i32(int32_t left, int32_t right) {
    if (right == 0) ube_integer_error("division by zero");
    if (left == INT32_MIN && right == -1) ube_integer_error("division overflow");
    return left / right;
}

int32_t ube_checked_mod_i32(int32_t left, int32_t right) {
    if (right == 0) ube_integer_error("remainder division by zero");
    if (left == INT32_MIN && right == -1) return 0;
    return left % right;
}

int32_t ube_checked_neg_i32(int32_t value) {
    if (value == INT32_MIN) ube_integer_error("negation overflow");
    return -value;
}

char* ube_string_concat(const char* left, const char* right) {
    if (left == NULL) left = "";
    if (right == NULL) right = "";
    const size_t left_length = strlen(left);
    const size_t right_length = strlen(right);
    if (right_length > SIZE_MAX - left_length) {
        fputs("UBE runtime: string size overflow\n", stderr);
        exit(70);
    }
    char* result = ube_allocate_string(left_length + right_length);
    memcpy(result, left, left_length);
    memcpy(result + left_length, right, right_length + 1);
    return result;
}

int32_t ube_string_compare(const char* left, const char* right) {
    if (left == NULL) left = "";
    if (right == NULL) right = "";
    const int comparison = strcmp(left, right);
    return comparison < 0 ? -1 : comparison > 0 ? 1 : 0;
}

int32_t ube_string_length(const char* value) {
    const size_t length = value != NULL ? strlen(value) : 0;
    if (length > INT32_MAX) {
        fputs("UBE runtime: string is too long for a Long length\n", stderr);
        exit(70);
    }
    return (int32_t)length;
}

int32_t ube_string_byte_at(const char* value, int32_t index) {
    const size_t length = value != NULL ? strlen(value) : 0;
    if (index < 0 || (size_t)index >= length) {
        fprintf(stderr, "UBE runtime: string byte index out of range: %" PRId32 "\n", index);
        exit(65);
    }
    return (int32_t)(unsigned char)value[index];
}

char* ube_string_slice(const char* value, int32_t start, int32_t length) {
    if (value == NULL) value = "";
    const size_t source_length = strlen(value);
    if (start < 0 || length < 0 || (size_t)start > source_length ||
        (size_t)length > source_length - (size_t)start) {
        fputs("UBE runtime: string slice is out of range\n", stderr);
        exit(65);
    }
    char* result = ube_allocate_string((size_t)length);
    memcpy(result, value + start, (size_t)length);
    result[length] = '\0';
    return result;
}

int32_t ube_string_index_of(const char* value, const char* needle, int32_t start) {
    if (value == NULL) value = "";
    if (needle == NULL) needle = "";
    const size_t value_length = strlen(value);
    if (start < 0 || (size_t)start > value_length) {
        fprintf(stderr, "UBE runtime: string search start is out of range: %" PRId32 "\n", start);
        exit(65);
    }
    const char* found = strstr(value + start, needle);
    if (found == NULL) return -1;
    const size_t index = (size_t)(found - value);
    if (index > INT32_MAX) {
        fputs("UBE runtime: string search result exceeds Long range\n", stderr);
        exit(70);
    }
    return (int32_t)index;
}

char* ube_string_from_byte(int32_t value) {
    if (value < 1 || value > 255) {
        fprintf(stderr, "UBE runtime: byte value is outside 1..255: %" PRId32 "\n", value);
        exit(65);
    }
    char* result = ube_allocate_string(1);
    result[0] = (char)(unsigned char)value;
    result[1] = '\0';
    return result;
}

char* ube_long_to_string(int32_t value) {
    char buffer[32];
    const int length = snprintf(buffer, sizeof(buffer), "%" PRId32, value);
    if (length < 0 || (size_t)length >= sizeof(buffer)) {
        fputs("UBE runtime: failed to format Long value\n", stderr);
        exit(70);
    }
    char* result = ube_allocate_string((size_t)length);
    memcpy(result, buffer, (size_t)length + 1);
    return result;
}

void ube_runtime_set_args(int32_t count, char** values) {
    ube_argument_count = count;
    ube_arguments = values;
}

int32_t ube_command_argument_count(void) {
    return ube_argument_count > 0 ? ube_argument_count - 1 : 0;
}

char* ube_command_argument(int32_t index) {
    if (index < 0 || index >= ube_command_argument_count() || ube_arguments == NULL) {
        fprintf(stderr, "UBE runtime: command argument index out of range: %" PRId32 "\n", index);
        exit(64);
    }
    return ube_arguments[index + 1];
}

char* ube_read_all_text(const char* path) {
    if (path == NULL) {
        fputs("UBE runtime: cannot read a null path\n", stderr);
        exit(66);
    }
    FILE* file = fopen(path, "rb");
    if (file == NULL) {
        fprintf(stderr, "UBE runtime: cannot open for reading: %s\n", path);
        exit(66);
    }
    if (fseek(file, 0, SEEK_END) != 0) {
        fprintf(stderr, "UBE runtime: cannot seek while reading: %s\n", path);
        fclose(file);
        exit(66);
    }
    const long end = ftell(file);
    if (end < 0 || fseek(file, 0, SEEK_SET) != 0) {
        fprintf(stderr, "UBE runtime: cannot determine file size: %s\n", path);
        fclose(file);
        exit(66);
    }
    char* result = ube_allocate_string((size_t)end);
    const size_t read = fread(result, 1, (size_t)end, file);
    if (read != (size_t)end) {
        fprintf(stderr, "UBE runtime: failed while reading: %s\n", path);
        fclose(file);
        exit(66);
    }
    if (memchr(result, '\0', read) != NULL) {
        fprintf(stderr, "UBE runtime: text file contains an embedded NUL byte: %s\n", path);
        fclose(file);
        exit(66);
    }
    if (fclose(file) != 0) {
        fprintf(stderr, "UBE runtime: failed while reading: %s\n", path);
        exit(66);
    }
    result[read] = '\0';
    return result;
}

int32_t ube_write_all_text(const char* path, const char* contents) {
    static LONG temporary_sequence;
    if (path == NULL || path[0] == '\0') {
        fputs("UBE runtime: cannot open for writing: invalid path\n", stderr);
        return 73;
    }
    if (contents == NULL) contents = "";

    const size_t path_length = strlen(path);
    if (path_length > 1048576 || path_length > SIZE_MAX - 64) {
        fprintf(stderr, "UBE runtime: cannot open for writing: %s\n", path);
        return 73;
    }
    char* temporary_path = malloc(path_length + 64);
    if (temporary_path == NULL) {
        fprintf(stderr, "UBE runtime: failed while writing: %s\n", path);
        return 74;
    }

    HANDLE file = INVALID_HANDLE_VALUE;
    for (int attempt = 0; attempt < 32; ++attempt) {
        const LONG sequence = InterlockedIncrement(&temporary_sequence);
        const int result = snprintf(temporary_path, path_length + 64,
                                    "%s.ube-tmp-%lu-%ld", path,
                                    (unsigned long)GetCurrentProcessId(),
                                    (long)sequence);
        if (result < 0 || (size_t)result >= path_length + 64) {
            free(temporary_path);
            fprintf(stderr, "UBE runtime: cannot open for writing: %s\n", path);
            return 73;
        }
        file = CreateFileA(temporary_path, GENERIC_WRITE, 0, NULL, CREATE_NEW,
                           FILE_ATTRIBUTE_TEMPORARY, NULL);
        if (file != INVALID_HANDLE_VALUE) break;
        if (GetLastError() != ERROR_FILE_EXISTS &&
            GetLastError() != ERROR_ALREADY_EXISTS) {
            free(temporary_path);
            fprintf(stderr, "UBE runtime: cannot open for writing: %s\n", path);
            return 73;
        }
    }
    if (file == INVALID_HANDLE_VALUE) {
        free(temporary_path);
        fprintf(stderr, "UBE runtime: cannot open for writing: %s\n", path);
        return 73;
    }

    const size_t length = strlen(contents);
    size_t offset = 0;
    int write_failed = 0;
    while (offset < length) {
        const size_t remaining = length - offset;
        const DWORD requested = remaining > 0x40000000u
            ? 0x40000000u : (DWORD)remaining;
        DWORD written = 0;
        if (!WriteFile(file, contents + offset, requested, &written, NULL) ||
            written != requested) {
            write_failed = 1;
            break;
        }
        offset += written;
    }
    if (!write_failed && !FlushFileBuffers(file)) write_failed = 1;
    if (!CloseHandle(file)) write_failed = 1;
    if (write_failed) {
        DeleteFileA(temporary_path);
        free(temporary_path);
        fprintf(stderr, "UBE runtime: failed while writing: %s\n", path);
        return 74;
    }
    if (!MoveFileExA(temporary_path, path,
                     MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
        DeleteFileA(temporary_path);
        free(temporary_path);
        fprintf(stderr, "UBE runtime: cannot open for writing: %s\n", path);
        return 73;
    }
    free(temporary_path);
    return 0;
}

int32_t ube_compiler_run_tool(const char* executable_path,
                              void** argument_array_reference,
                              int32_t argument_count) {
    if (executable_path == NULL || executable_path[0] == '\0' || argument_count < 0) {
        return -1;
    }
    if (argument_count > 4096) {
        return -1;
    }

    const struct ube_array* arguments = NULL;
    if (argument_count > 0) {
        if (argument_array_reference == NULL || *argument_array_reference == NULL) {
            return -1;
        }
        arguments = *argument_array_reference;
        const int64_t available = (int64_t)arguments->upper - arguments->lower + 1;
        if (arguments->lower != 0 || arguments->element_size != sizeof(char*) ||
            available < argument_count) {
            return -1;
        }
    }

    /* The MinGW _spawnv adapter supplies the child's executable identity;
       this array contains only the distinct user arguments. */
    const char* const* values = arguments != NULL
        ? (const char* const*)arguments->data : NULL;
    size_t command_capacity = strlen(executable_path) * 2 + 4;
    for (int32_t index = 0; index < argument_count; ++index) {
        const char* value = values[index] != NULL ? values[index] : "";
        const size_t length = strlen(value);
        if (length > 524288 || command_capacity > 1048576 - length * 2 - 4) {
            return -1;
        }
        command_capacity += length * 2 + 4;
    }
    char* command_line = malloc(command_capacity);
    if (command_line == NULL) {
        return -2;
    }

    size_t output = 0;
    const char* parts[2] = { executable_path, NULL };
    for (int32_t part_index = -1; part_index < argument_count; ++part_index) {
        const char* value = part_index < 0 ? parts[0]
            : (values[part_index] != NULL ? values[part_index] : "");
        if (output != 0) command_line[output++] = ' ';
        command_line[output++] = '"';
        size_t backslashes = 0;
        for (size_t input = 0;; ++input) {
            const char current = value[input];
            if (current == '\\') {
                ++backslashes;
                continue;
            }
            if (current == '"' || current == '\0') {
                for (size_t copy = 0; copy < backslashes * 2; ++copy) {
                    command_line[output++] = '\\';
                }
                backslashes = 0;
                if (current == '"') {
                    command_line[output++] = '\\';
                    command_line[output++] = '"';
                    continue;
                }
                break;
            }
            while (backslashes > 0) {
                command_line[output++] = '\\';
                --backslashes;
            }
            command_line[output++] = current;
        }
        command_line[output++] = '"';
    }
    command_line[output] = '\0';

    STARTUPINFOA startup;
    PROCESS_INFORMATION process;
    memset(&startup, 0, sizeof(startup));
    memset(&process, 0, sizeof(process));
    startup.cb = sizeof(startup);
    const BOOL started = CreateProcessA(executable_path, command_line, NULL, NULL,
                                        TRUE, 0, NULL, NULL, &startup, &process);
    free(command_line);
    if (!started) return -2;
    const DWORD wait_result = WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exit_code = 0;
    const BOOL got_exit = wait_result == WAIT_OBJECT_0 &&
                          GetExitCodeProcess(process.hProcess, &exit_code);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    if (!got_exit) return -2;
    if (exit_code > INT32_MAX) return -3;
    return (int32_t)exit_code;
}

int32_t ube_compiler_delete_file(const char* path) {
    if (path == NULL || path[0] == '\0') return -1;
    if (DeleteFileA(path)) return 0;
    const DWORD error = GetLastError();
    if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) return 0;
    return -2;
}
