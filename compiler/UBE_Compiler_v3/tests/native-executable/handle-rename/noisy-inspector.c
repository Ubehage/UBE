#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(void) {
    char out[1024], err[1024];
    const char *setting = getenv("UBE_TEST_STREAM_BYTES");
    long remaining = setting ? strtol(setting, NULL, 10) : 131072;
    if (remaining < 0 || remaining > 131072) return 2;
    memset(out, 'A', sizeof(out)); memset(err, 'B', sizeof(err));
    while (remaining > 0) {
        size_t count = remaining < (long)sizeof(out) ? (size_t)remaining : sizeof(out);
        if (fwrite(out, 1, count, stdout) != count || fwrite(err, 1, count, stderr) != count) return 1;
        remaining -= (long)count;
    }
    return fflush(stdout) == 0 && fflush(stderr) == 0 ? 0 : 1;
}
