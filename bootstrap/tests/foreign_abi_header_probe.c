#include "foreign-library.h"

static void verify_generated_declarations(void) {
    (void)&ube_library_abi_major;
    (void)&ube_library_export_signature_hashes;
    (void)&ube_export_41646456616C756573;
    (void)&ube_export_4372656174654C656173656456616C7565;
}

int main(void) {
    verify_generated_declarations();
    return 0;
}
