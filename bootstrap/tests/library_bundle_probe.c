#include <stdint.h>
#include <stdio.h>

int32_t ube_compiler_validate_library_bundle(const char* path, const char* target,
                                              const char* version, const char* interface_hash);

int main(int argc, char** argv) {
    if (argc != 3) {
        fputs("usage: library_bundle_probe <bundle.UBL> <interface-sha256>\n", stderr);
        return 2;
    }
    if (ube_compiler_validate_library_bundle(
            argv[1], "x86_64-w64-windows-gnu", "1.0.0-rp8", argv[2]) != 0) {
        fputs("valid bundle was rejected\n", stderr);
        return 1;
    }
    if (ube_compiler_validate_library_bundle(
            argv[1], "x86_64-unknown-linux-gnu", "1.0.0-rp8", argv[2]) == 0) {
        fputs("incompatible target was accepted\n", stderr);
        return 1;
    }
    puts("library bundle probe passed");
    return 0;
}
