#include <stdint.h>
#include <stdio.h>

int32_t ube_compiler_validate_resource(const char* path);

int main(int argc, char** argv) {
    if (argc != 3) {
        fputs("usage: resource_probe <valid.UBR> <corrupt.UBR>\n", stderr);
        return 2;
    }
    if (ube_compiler_validate_resource(argv[1]) != 0) {
        fputs("valid resource was rejected\n", stderr);
        return 1;
    }
    if (ube_compiler_validate_resource(argv[2]) == 0) {
        fputs("corrupt resource was accepted\n", stderr);
        return 1;
    }
    puts("resource probe passed");
    return 0;
}
