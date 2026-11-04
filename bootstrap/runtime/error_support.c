#include <stddef.h>
#include <stdint.h>

/* Private linked substrate, shared with the bootstrap runtime by inclusion.
   Native outputs compile this file alone, without managed runtime facilities.
   Each native thread owns this fixed, initially zero, allocation-free record. */
struct ube_error_state {
    int32_t number;
    uint64_t revision;
    char description[512];
    char source[256];
};

static _Thread_local struct ube_error_state ube_thread_error;

static inline __attribute__((always_inline)) struct ube_error_state* ube_current_error_state(void) {
    return &ube_thread_error;
}

/* Volatile byte stores prevent recognition as an external memcpy/memset call.
   Inlining keeps both recording paths closed even in unoptimized bootstrap
   builds. Linked machine-code inspection remains an acceptance requirement. */
static inline __attribute__((always_inline)) void ube_error_copy_text(
    volatile char* destination, size_t capacity, const char* source) {
    size_t copied = 0;
    if (source != NULL) {
        while (copied + 1u < capacity && source[copied] != '\0') {
            destination[copied] = source[copied];
            ++copied;
        }
    }
    destination[copied] = '\0';
}

static inline __attribute__((always_inline)) void ube_error_record(
    int32_t number, const char* description, const char* source) {
    struct ube_error_state* state = &ube_thread_error;
    ++state->revision;
    if (state->revision == 0) ++state->revision;
    state->number = number;
    ube_error_copy_text(state->description, sizeof(state->description), description);
    ube_error_copy_text(state->source, sizeof(state->source), source);
}

/* Success never invokes these recording operations or implicitly clears Err. */
void ube_err_set(int32_t number, const char* description, const char* source) {
    ube_error_record(number, description, source);
}

void ube_err_set_stack_exhausted(void) {
    ube_error_record(28, "out of stack space", "UBE.Runtime");
}

int32_t ube_err_number(void) {
    return ube_current_error_state()->number;
}

void ube_err_clear(void) {
    uint64_t revision = ube_thread_error.revision + 1u;
    if (revision == 0) revision = 1u;
    volatile unsigned char* bytes = (volatile unsigned char*)&ube_thread_error;
    for (size_t index = 0; index < sizeof(ube_thread_error); ++index) bytes[index] = 0;
    ube_thread_error.revision = revision;
}
