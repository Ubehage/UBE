#include <stdint.h>
#include <stdbool.h>
struct native_byte {uint8_t value;};
struct native_integer {int16_t value;};
struct native_long {int32_t value;};
_Static_assert(sizeof(struct native_byte)==1 && _Alignof(struct native_byte)==1,"Byte aggregate");
_Static_assert(sizeof(struct native_integer)==2 && _Alignof(struct native_integer)==2,"Integer aggregate");
_Static_assert(sizeof(struct native_long)==4 && _Alignof(struct native_long)==4,"Long aggregate");
extern bool literal0(void),literal2(void);
extern uint8_t literal4(void),literal6(void);
extern int16_t literal8(void),literal10(void);
extern int32_t literal12(void),literal14(void);
extern int64_t literal16(void),literal18(void);
extern struct native_byte literal20(void),literal22(void);
extern struct native_integer literal24(void),literal26(void);
extern struct native_long literal28(void),literal30(void);
int main(void) {
    if(literal0()!=false || literal2()!=true || literal4()!=0 || literal6()!=255)return 1;
    if(literal8()!=INT16_MIN || literal10()!=INT16_MAX || literal12()!=INT32_MIN || literal14()!=INT32_MAX)return 2;
    if(literal16()!=INT64_MIN || literal18()!=INT64_MAX)return 3;
    if(literal20().value!=0 || literal22().value!=255)return 4;
    if(literal24().value!=INT16_MIN || literal26().value!=INT16_MAX)return 5;
    if(literal28().value!=INT32_MIN || literal30().value!=INT32_MAX)return 6;
    return 0;
}
