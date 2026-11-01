#ifndef UBE_PROJECT_DIAGNOSTIC_TEST_LAYOUT_H
#define UBE_PROJECT_DIAGNOSTIC_TEST_LAYOUT_H
#include <stdint.h>
/* Independent target-native declarations checked against the emitted layouts. */
struct position {int32_t byte,scalar,line,column;};
struct source_failure {int32_t kind;struct position position;};
struct unit_failure {int32_t kind,first,last;};
struct input;
struct failure {
    int32_t kind,code,package,source,location,first,last;
    struct source_failure input;int32_t file;struct unit_failure unit;struct input* context;
};
struct limits {int32_t manifest,packages,sources,source,total_source,path,total_path,metadata,tokens,nodes,pending,depth;};
#endif
