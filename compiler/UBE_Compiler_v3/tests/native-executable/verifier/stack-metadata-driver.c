#include <stdint.h>

#ifndef EXPECTED_FRAME
#error EXPECTED_FRAME must be supplied by the test
#endif
int metadata_caller(int);
int check_frame(uint64_t size) { return size == (uint64_t)EXPECTED_FRAME; }
void observe_frame(volatile unsigned char *frame) { (void)frame[8191]; }
int main(void) { return metadata_caller(7) == 8 ? 0 : 1; }
