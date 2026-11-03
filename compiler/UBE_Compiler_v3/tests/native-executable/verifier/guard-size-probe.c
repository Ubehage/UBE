extern int recursion_guard(void);
__declspec(noinline) int target(int value) {
#ifdef INCLUDE_GUARD
    if (!recursion_guard()) return -1;
#endif
    return value + 1;
}
