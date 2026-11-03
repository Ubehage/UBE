static volatile int input_value = 4;
static volatile int calls = 0;

__declspec(noinline) int double_observed(int value) {
#ifdef MUTATE_CALLS
    calls = calls + 2;
#else
    calls = calls + 1;
#endif
    return value * 2;
}

int main(void) {
    int result = double_observed(input_value);
    return result == 8 && calls == 1 ? 8 : 99;
}
