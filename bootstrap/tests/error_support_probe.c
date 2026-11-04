#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "../runtime/error_support.c"

_Static_assert(offsetof(struct ube_error_state, number) == 0, "number ABI");
_Static_assert(offsetof(struct ube_error_state, revision) == 8, "revision ABI");
_Static_assert(offsetof(struct ube_error_state, description) == 16, "description ABI");
_Static_assert(offsetof(struct ube_error_state, source) == 528, "source ABI");
_Static_assert(sizeof(struct ube_error_state) == 784, "record ABI");

/* Independent byte-level oracle: no production copying or revision helper. */
static int verify_record(void) {
    struct ube_error_state* state = ube_current_error_state();
    struct ube_error_state expected;
    memset(&expected, 0, sizeof(expected));
    if (memcmp(state, &expected, sizeof(expected)) != 0) return 1;
    const uint64_t revisions[] = {0, 1, UINT64_MAX - 1, UINT64_MAX};
    for (size_t index = 0; index < sizeof(revisions)/sizeof(revisions[0]); ++index) {
        struct ube_error_state initial, ordinary;
        memset(&initial, 0x5a, sizeof(initial));
        initial.revision = revisions[index];
        *state = initial;
        ube_err_set(28, "out of stack space", "UBE.Runtime");
        ordinary = *state;
        *state = initial;
        ube_err_set_stack_exhausted();
#ifdef WRONG_STACK_ERROR_CONTROL
        state->number = 29;
#endif
        expected = initial;
        expected.number = 28;
        expected.revision = revisions[index] == UINT64_MAX ? 1 : revisions[index] + 1;
        memcpy(expected.description, "out of stack space", 19);
        memcpy(expected.source, "UBE.Runtime", 12);
        if (memcmp(state, &expected, sizeof(expected)) != 0 ||
            memcmp(&ordinary, &expected, sizeof(expected)) != 0) return 2;
        struct ube_error_state preserved = *state;
        if (ube_err_number() != 28 || memcmp(state, &preserved, sizeof(preserved)) != 0) return 3;
        state->revision = revisions[index];
        ube_err_clear();
        memset(&expected, 0, sizeof(expected));
        expected.revision = revisions[index] == UINT64_MAX ? 1 : revisions[index] + 1;
        if (memcmp(state, &expected, sizeof(expected)) != 0) return 4;
    }
    char description[1024], source[1024];
    memset(description, 'd', sizeof(description)); description[1023] = 0;
    memset(source, 's', sizeof(source)); source[1023] = 0;
    ube_err_set(-123, description, source);
    if (state->number != -123 || state->description[511] || state->source[255]) return 5;
    for (size_t index = 0; index < 511; ++index) if (state->description[index] != 'd') return 6;
    for (size_t index = 0; index < 255; ++index) if (state->source[index] != 's') return 7;
    ube_err_set(6, NULL, NULL);
    if (state->number != 6 || state->description[0] || state->source[0] ||
        state->description[1] != 'd' || state->source[1] != 's') return 8;
    /* Visible error fields belong entirely to the latest error, not a merge. */
    ube_err_set(5, "older description", "older source");
    uint64_t revision = state->revision;
    ube_err_set(6, NULL, "replacement source");
#ifdef STALE_ERROR_DESCRIPTION_CONTROL
    memcpy(state->description, "older description", 18);
#endif
    if (state->number != 6 || strcmp(state->description, "") != 0 ||
        strcmp(state->source, "replacement source") != 0 ||
        state->revision != revision + 1) return 9;
    revision = state->revision;
    ube_err_set(11, "replacement description", NULL);
#ifdef STALE_ERROR_SOURCE_CONTROL
    memcpy(state->source, "replacement source", 19);
#endif
    if (state->number != 11 || strcmp(state->description, "replacement description") != 0 ||
        strcmp(state->source, "") != 0 || state->revision != revision + 1) return 10;
    struct ube_error_state preserved = *state;
    if (ube_err_number() != 11 || memcmp(state, &preserved, sizeof preserved) != 0) return 11;
    ube_err_clear();
    if (ube_err_number() != 0 || state->description[0] || state->source[0]) return 12;
    return 0;
}

int main(void) {
    int result = verify_record();
    if (result) { fprintf(stderr, "record oracle failed: %d\n", result); return 1; }
    puts("error record fields, clear, wrap, bounded text and specialized setter passed");
    return 0;
}
