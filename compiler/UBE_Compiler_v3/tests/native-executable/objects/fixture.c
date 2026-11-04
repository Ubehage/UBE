volatile int initialized_value=17;
volatile unsigned char zero_values[8192];
__attribute__((noinline)) int imported_call(int value){return value+initialized_value+zero_values[1];}
int main(void){return imported_call(4)==21?0:1;}
