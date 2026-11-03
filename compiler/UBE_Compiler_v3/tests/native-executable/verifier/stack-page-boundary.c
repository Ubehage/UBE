#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#define STACK_REGION_SCAN
#include "stack-committed-pages.h"

static int regions_match(ULONG_PTR here, ULONG_PTR bound, int expected_ok, ULONG_PTR expected_floor) {
    ULONG_PTR floor = 0; unsigned int count = 0;
    int ok = stack_writable_floor_regions(here, bound, &floor, &count);
    return ok == expected_ok && (!ok || (floor == expected_floor && count > 0));
}

int main(void) {
    SYSTEM_INFO info;
    GetSystemInfo(&info);
    if (!info.dwPageSize) return 1;
    SIZE_T page = info.dwPageSize;
    unsigned char *memory = VirtualAlloc(NULL, page * 8, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
    if (!memory) return 2;
    int result = 1;
    DWORD prior = 0;
    if (!VirtualProtect(memory + page, page, PAGE_NOACCESS, &prior) ||
        !VirtualProtect(memory + 2 * page, page, PAGE_READWRITE | PAGE_GUARD, &prior)) goto done;
    MEMORY_BASIC_INFORMATION guard = {0}, inaccessible = {0};
    if (!VirtualQuery(memory + 2 * page, &guard, sizeof(guard)) || !(guard.Protect & PAGE_GUARD) ||
        !VirtualQuery(memory + page, &inaccessible, sizeof(inaccessible)) || (inaccessible.Protect & 0xff) != PAGE_NOACCESS) goto done;
    ULONG_PTR low = 0; unsigned int count = 0;
    if (!stack_writable_floor((ULONG_PTR)(memory + 6 * page + 1), (ULONG_PTR)memory, &low, &count) ||
        low != (ULONG_PTR)(memory + 3 * page) || count != 4) goto done;
    if (!regions_match((ULONG_PTR)(memory + 6 * page + 1), (ULONG_PTR)memory, 1, low)) goto done;
    if (stack_writable_floor((ULONG_PTR)(memory + 2 * page + 1), (ULONG_PTR)memory, &low, &count)) goto done;
    if (!regions_match((ULONG_PTR)(memory + 2 * page + 1), (ULONG_PTR)memory, 0, 0)) goto done;
    if (!VirtualProtect(memory + 2 * page, page, PAGE_READWRITE, &prior)) goto done;
    if (!stack_writable_floor((ULONG_PTR)(memory + 6 * page + 1), (ULONG_PTR)memory, &low, &count) ||
        low != (ULONG_PTR)(memory + 2 * page) || count != 5) goto done;
    if (!regions_match((ULONG_PTR)(memory + 6 * page + 1), (ULONG_PTR)memory, 1, low)) goto done;
    if (stack_writable_floor((ULONG_PTR)(memory + page + 1), (ULONG_PTR)memory, &low, &count)) goto done;
    if (!VirtualFree(memory + 3 * page, page, MEM_DECOMMIT)) goto done;
    MEMORY_BASIC_INFORMATION uncommitted = {0};
    if (!VirtualQuery(memory + 3 * page, &uncommitted, sizeof(uncommitted)) || uncommitted.State != MEM_RESERVE) goto done;
    if (!stack_writable_floor((ULONG_PTR)(memory + 6 * page + 1), (ULONG_PTR)memory, &low, &count) ||
        low != (ULONG_PTR)(memory + 4 * page) || count != 3) goto done;
    if (!regions_match((ULONG_PTR)(memory + 6 * page + 1), (ULONG_PTR)memory, 1, low)) goto done;
    if (stack_writable_floor((ULONG_PTR)(memory + 3 * page + 1), (ULONG_PTR)memory, &low, &count)) goto done;
    if (!stack_writable_floor((ULONG_PTR)(memory + 6 * page + 1), (ULONG_PTR)(memory + 5 * page), &low, &count) ||
        low != (ULONG_PTR)(memory + 5 * page) || count != 2) goto done;
    if (stack_writable_floor((ULONG_PTR)(memory + 6 * page + 1), (ULONG_PTR)(memory + 7 * page), &low, &count)) goto done;
    if (!VirtualProtect(memory + 5 * page, page, PAGE_NOACCESS, &prior)) goto done;
    MEMORY_BASIC_INFORMATION changed = {0};
    if (!VirtualQuery(memory + 5 * page, &changed, sizeof(changed)) || (changed.Protect & 0xff) != PAGE_NOACCESS) goto done;
    puts("guard, no-access, uncommitted, bound and stale-observation controls passed");
    result = 0;
done:
    if (!VirtualFree(memory, 0, MEM_RELEASE)) return 3;
    return result;
}
