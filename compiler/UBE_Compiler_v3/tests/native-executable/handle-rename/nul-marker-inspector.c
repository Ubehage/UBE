#include <stdio.h>
int main(void) {
    static const char report[] = "Machine: IMAGE_FILE_MACHINE_AMD64\nIMAGE_FILE_EXECUTABLE_IMAGE\nImageOptionalHeader {\nMagic: 0x20B\n\0    IMAGE_FILE_DLL (0x2000)\n";
    return fwrite(report, 1, sizeof(report) - 1, stdout) == sizeof(report) - 1 && fflush(stdout) == 0 ? 0 : 1;
}
