#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#define STACK_WALK_METRICS
#define STACK_REGION_SCAN
#include "stack-committed-pages.h"

static int measure(unsigned char *memory, SIZE_T page, unsigned int steps, int by_region, uint64_t *queries) {
    stack_page_queries = 0;
    for (unsigned int i = 1; i <= steps; ++i) {
        ULONG_PTR floor = 0; unsigned int observed = 0;
        ULONG_PTR marker = (ULONG_PTR)(memory + (SIZE_T)(i - 1) * page + 1);
        int ok = by_region ? stack_writable_floor_regions(marker, (ULONG_PTR)memory, &floor, &observed) :
                             stack_writable_floor(marker, (ULONG_PTR)memory, &floor, &observed);
        if (!ok || floor != (ULONG_PTR)memory || observed != (by_region ? 1U : i)) return 0;
    }
    *queries = stack_page_queries;
    return 1;
}

static int measure_fragmented(unsigned char *memory, SIZE_T page, int by_region, uint64_t *queries) {
    stack_page_queries = 0;
    for (unsigned int i = 0; i < 16; ++i) {
        ULONG_PTR floor = 0; unsigned int observed = 0;
        ULONG_PTR marker = (ULONG_PTR)(memory + (SIZE_T)(2 * i) * page + 1);
        int ok = by_region ? stack_writable_floor_regions(marker, (ULONG_PTR)memory, &floor, &observed) :
                             stack_writable_floor(marker, (ULONG_PTR)memory, &floor, &observed);
        if (!ok || floor != marker - 1 || observed != (by_region ? 2 * i + 1 : 1U)) return 0;
    }
    *queries = stack_page_queries;
    return 1;
}

int main(void) {
    SYSTEM_INFO info; GetSystemInfo(&info);
    if (!info.dwPageSize) return 1;
    SIZE_T page = info.dwPageSize;
    unsigned char *memory = VirtualAlloc(NULL, page * 32, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
    if (!memory) return 2;
    uint64_t small = 0, large = 0, small_regions = 0, large_regions = 0, fragmented_pages = 0, fragmented_regions = 0;
    int ok = measure(memory, page, 16, 0, &small) && measure(memory, page, 32, 0, &large) &&
             measure(memory, page, 16, 1, &small_regions) && measure(memory, page, 32, 1, &large_regions);
    DWORD old_protection = 0;
    for (unsigned int i = 1; ok && i < 32; i += 2) {
        if (!VirtualProtect(memory + (SIZE_T)i * page, page, PAGE_READONLY, &old_protection)) ok = 0;
    }
    if (ok) ok = measure_fragmented(memory, page, 0, &fragmented_pages) &&
                 measure_fragmented(memory, page, 1, &fragmented_regions);
    if (!VirtualFree(memory, 0, MEM_RELEASE)) return 3;
    if (!ok || small != 136 || large != 528 || large <= 2 * small || small_regions != 16 || large_regions != 32 ||
        fragmented_pages != 31 || fragmented_regions != 256) return 1;
    printf("page queries=136,528; region queries=16,32; fragmented page=31 region=256\n");
    return 0;
}
