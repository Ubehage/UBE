#include <string.h>

int main(int argument_count, char** arguments) {
    return argument_count * 10 +
           (argument_count > 1 && strcmp(arguments[1], "first argument") == 0 ? 1 : 0) +
           (argument_count > 2 && strcmp(arguments[2], "--flag") == 0 ? 2 : 0);
}
