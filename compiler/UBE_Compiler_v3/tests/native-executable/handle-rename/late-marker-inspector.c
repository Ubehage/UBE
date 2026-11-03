#include <stdio.h>

int main(void) {
    puts("Machine: IMAGE_FILE_MACHINE_AMD64\nIMAGE_FILE_EXECUTABLE_IMAGE\nImageOptionalHeader {\nMagic: 0x20B");
    for (int i = 0; i < 4097; ++i) if (putchar('A') == EOF) return 1;
    puts("\n    IMAGE_FILE_DLL (0x2000)");
    return ferror(stdout) ? 1 : 0;
}
