#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>
struct limits { int64_t payload,llvm,identities,pending,work,depth,candidate; };
struct usage { int64_t payload,peak_payload,llvm,identities,pending,peak_pending,work,depth,peak_depth; };
struct failure { int32_t code,resource; };
extern void native_defaults(struct limits*);
extern int32_t native_charge(struct limits*,struct usage*,int32_t,int64_t,struct failure*);
extern int32_t native_release(struct usage*,int32_t,int64_t,struct failure*);
extern int32_t native_candidate(struct limits*,int64_t,struct failure*);
extern void ube_err_set(int32_t,const char*,const char*);
extern int32_t ube_err_number(void);
static unsigned assertions;
#define CHECK(x) do { ++assertions; if(!(x)) { fprintf(stderr,"native accounting line %d: %s\n",__LINE__,#x); return 1; } } while(0)
static int64_t current(const struct usage* u,int category) {
    switch(category) {
    case 1:return u->payload; case 2:return u->llvm; case 3:return u->identities;
    case 4:return u->pending; case 5:return u->work; case 6:return u->depth;
    default:return -1;
    }
}
static int64_t high(const struct usage* u,int category) {
    switch(category) {case 1:return u->peak_payload;case 4:return u->peak_pending;case 6:return u->peak_depth;default:return -1;}
}
int main(void) {
    CHECK(sizeof(struct limits)==56 && sizeof(struct usage)==72 && sizeof(struct failure)==8);
    struct limits l={0}; native_defaults(&l);
    CHECK(l.payload==1073741824 && l.llvm==268435456 && l.identities==4194304 && l.pending==1048576 && l.work==268435456 && l.depth==256 && l.candidate==268435456);
    ube_err_set(77,"preserve","accounting oracle");
    /* Distinct caps expose charging one resource against another resource's
       allowance. Inspect untouched categories independently as well. */
    const int64_t caps[]={0,7,11,13,17,19,23};
    for(int category=1;category<=6;++category) {
        struct usage u={0}; struct failure f={123,456};
        l=(struct limits){7,11,13,17,19,23,29};
        CHECK(native_charge(&l,&u,category,caps[category],&f)==1 && f.code==0);
        for(int other=1;other<=6;++other) CHECK(current(&u,other)==(other==category ? caps[category] : 0));
        struct usage before=u;
        CHECK(native_charge(&l,&u,category,1,&f)==0 && f.code==1502 && f.resource==category && memcmp(&u,&before,sizeof u)==0);
    }
    for(int category=1;category<=6;++category) {
        struct usage u={0},before;
        struct failure f={123,456};
        l=(struct limits){16,16,16,16,16,16,16};
        CHECK(native_charge(&l,&u,category,0,&f)==1 && f.code==0 && f.resource==0 && current(&u,category)==0);
        CHECK(native_charge(&l,&u,category,7,&f)==1 && current(&u,category)==7);
        CHECK(native_charge(&l,&u,category,9,&f)==1 && current(&u,category)==16);
        before=u;
        CHECK(native_charge(&l,&u,category,1,&f)==0 && f.code==1502 && f.resource==category && memcmp(&u,&before,sizeof u)==0);
        CHECK(native_charge(&l,&u,category,-1,&f)==0 && f.code==1509 && f.resource==0 && memcmp(&u,&before,sizeof u)==0);
        CHECK(native_charge(&l,&u,category,INT64_MIN,&f)==0 && f.code==1509 && memcmp(&u,&before,sizeof u)==0);
        if(category==1 || category==4 || category==6) {
            CHECK(high(&u,category)==16);
            CHECK(native_release(&u,category,17,&f)==0 && f.code==1509 && memcmp(&u,&before,sizeof u)==0);
            CHECK(native_release(&u,category,7,&f)==1 && current(&u,category)==9 && high(&u,category)==16);
            CHECK(native_release(&u,category,9,&f)==1 && current(&u,category)==0 && high(&u,category)==16);
            CHECK(native_charge(&l,&u,category,16,&f)==1 && current(&u,category)==16 && high(&u,category)==16);
        } else CHECK(native_release(&u,category,1,&f)==0 && f.code==1509 && memcmp(&u,&before,sizeof u)==0);
        l=(struct limits){0}; u=(struct usage){0};
        CHECK(native_charge(&l,&u,category,0,&f)==1);
        before=u;
        CHECK(native_charge(&l,&u,category,1,&f)==0 && f.code==1502 && f.resource==category && memcmp(&u,&before,sizeof u)==0);
        l=(struct limits){INT64_MAX,INT64_MAX,INT64_MAX,INT64_MAX,INT64_MAX,INT64_MAX,INT64_MAX};
        CHECK(native_charge(&l,&u,category,INT64_MAX-1,&f)==1 && current(&u,category)==INT64_MAX-1);
        CHECK(native_charge(&l,&u,category,1,&f)==1 && current(&u,category)==INT64_MAX);
        before=u;
        CHECK(native_charge(&l,&u,category,1,&f)==0 && f.code==1502 && memcmp(&u,&before,sizeof u)==0);
        CHECK(ube_err_number()==77);
        l=(struct limits){0};
        CHECK(native_charge(&l,&u,category,0,&f)==0 && f.code==1502 && memcmp(&u,&before,sizeof u)==0);
    }
    struct usage u={0},before=u; struct failure f={123,456};
    l=(struct limits){16,16,16,16,16,16,16};
    CHECK(native_charge(&l,&u,0,0,&f)==0 && f.code==1509 && memcmp(&u,&before,sizeof u)==0);
    CHECK(native_charge(&l,&u,8,0,&f)==0 && f.code==1509 && memcmp(&u,&before,sizeof u)==0);
    CHECK(native_release(&u,1,-1,&f)==0 && f.code==1509 && memcmp(&u,&before,sizeof u)==0);
    CHECK(native_candidate(&l,0,&f)==1 && f.code==0);
    CHECK(native_candidate(&l,15,&f)==1 && f.code==0);
    CHECK(native_candidate(&l,16,&f)==1 && f.code==0);
    CHECK(native_candidate(&l,17,&f)==0 && f.code==1502 && f.resource==8);
    CHECK(native_candidate(&l,-1,&f)==0 && f.code==1509 && f.resource==0);
    l.payload=-1;
    CHECK(native_charge(&l,&u,2,0,&f)==0 && f.code==1509 && memcmp(&u,&before,sizeof u)==0);
    CHECK(native_candidate(&l,0,&f)==0 && f.code==1509);
    CHECK(ube_err_number()==77);
    printf("PASS native resource accounting %u assertions\n",assertions);
    return 0;
}
