#include <stdio.h>

static char events[3];
static unsigned int used;
static void observe(char event) {
    if (used < 2) events[used++] = event;
}
static void library_initializer(void) { observe('L'); }
static void executable_initializer(void) { observe('E'); }

int main(void) {
#ifdef REVERSE_INITIALIZERS_CONTROL
    executable_initializer(); library_initializer();
#else
    library_initializer(); executable_initializer();
#endif
    if (used != 2) return 1;
    puts(events);
    return 0;
}
