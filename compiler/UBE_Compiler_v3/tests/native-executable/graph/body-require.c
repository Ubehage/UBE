/* Controlled adapter for the existing single-module value/call fixtures.
   It has no initialization behavior. The separate integration fixture links
   the production state helper and actual checked module initializers. */
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
bool body_require(int32_t owner,int32_t lexical) __asm__("ube.module.require");
bool body_require(int32_t owner,int32_t lexical){if(lexical!=0 || (owner!=-1 && owner!=0))exit(98);return true;}
