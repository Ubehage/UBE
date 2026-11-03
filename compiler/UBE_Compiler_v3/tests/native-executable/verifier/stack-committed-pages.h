#ifndef UBE_TEST_STACK_COMMITTED_PAGES_H
#define UBE_TEST_STACK_COMMITTED_PAGES_H

#ifdef STACK_WALK_METRICS
static uint64_t stack_page_queries;
#define STACK_QUERY(address, info) (++stack_page_queries, VirtualQuery((address), (info), sizeof(*(info))))
#else
#define STACK_QUERY(address, info) VirtualQuery((address), (info), sizeof(*(info)))
#endif

/* Test-only page walk. Its caller must separately establish stack bounds. */
static int stack_writable_floor(ULONG_PTR here, ULONG_PTR bound, ULONG_PTR *floor, unsigned int *count) {
    SYSTEM_INFO system;
    GetSystemInfo(&system);
    if (!system.dwPageSize || bound >= here) return 0;
    ULONG_PTR page_size = system.dwPageSize;
    ULONG_PTR page = here - here % page_size;
    if (page < bound) return 0;
    MEMORY_BASIC_INFORMATION region = {0};
    if (!STACK_QUERY((void *)page, &region) || region.State != MEM_COMMIT ||
        (region.Protect & PAGE_GUARD) || (region.Protect & 0xff) != PAGE_READWRITE) return 0;
    ULONG_PTR allocation = (ULONG_PTR)region.AllocationBase;
    unsigned int pages = 1;
    while (page >= page_size && page-page_size >= bound && pages < 4096) {
        MEMORY_BASIC_INFORMATION previous = {0};
        ULONG_PTR candidate = page-page_size;
        if (!STACK_QUERY((void *)candidate, &previous)) return 0;
        if ((ULONG_PTR)previous.AllocationBase != allocation || previous.State != MEM_COMMIT ||
#ifndef IGNORE_PAGE_GUARD_CONTROL
            (previous.Protect & PAGE_GUARD) ||
#endif
            (previous.Protect & 0xff) != PAGE_READWRITE) break;
        page = candidate;
        ++pages;
    }
    *floor = page;
    *count = pages;
    return 1;
}

#ifdef STACK_REGION_SCAN
/* Independent experimental forward scan over the same test-owned range. */
static int stack_writable_floor_regions(ULONG_PTR here, ULONG_PTR bound, ULONG_PTR *floor, unsigned int *count) {
    SYSTEM_INFO system;
    GetSystemInfo(&system);
    if (!system.dwPageSize || bound >= here || bound % system.dwPageSize) return 0;
    ULONG_PTR cursor = bound, run = 0, allocation = 0;
    unsigned int regions = 0;
    int writable = 0;
    while (cursor <= here && regions < 4096) {
        MEMORY_BASIC_INFORMATION region = {0};
        if (!STACK_QUERY((void *)cursor, &region) || (ULONG_PTR)region.BaseAddress != cursor ||
            region.RegionSize > UINTPTR_MAX-cursor || !region.RegionSize) return 0;
        ULONG_PTR end = cursor + region.RegionSize;
        int allowed = region.State == MEM_COMMIT && (region.Protect & 0xff) == PAGE_READWRITE;
#if !defined(IGNORE_PAGE_GUARD_CONTROL) && !defined(IGNORE_REGION_GUARD_CONTROL)
        allowed = allowed && !(region.Protect & PAGE_GUARD);
#endif
        if (!allowed) writable = 0;
        else if (!writable || allocation != (ULONG_PTR)region.AllocationBase) {
            run = cursor; allocation = (ULONG_PTR)region.AllocationBase; writable = 1;
        }
        ++regions;
        if (here < end) {
            if (!writable) return 0;
            *floor = run; *count = regions; return 1;
        }
        cursor = end;
    }
    return 0;
}
#endif
#endif
