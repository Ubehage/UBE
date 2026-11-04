/* Independent test-only oracle: SDK structures, not production field offsets.
   Input is a Clang-generated artifact, not an untrusted file parser. */
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
static void print_bytes(const unsigned char* p,size_t n){for(size_t i=0;i<n;++i)printf("%02x",p[i]);}
static size_t short_length(const unsigned char* p){size_t n=0;while(n<8 && p[n])++n;return n;}
int main(int argc,char** argv){
 if(argc!=2)return 1;
 FILE* f=fopen(argv[1],"rb");if(!f)return 2;
 if(fseek(f,0,SEEK_END))return 3;
 long length=ftell(f);if(length<0 || fseek(f,0,SEEK_SET))return 4;
 unsigned char* bytes=malloc((size_t)length);if(!bytes)return 5;
 if(fread(bytes,1,(size_t)length,f)!=(size_t)length || fclose(f))return 6;
 IMAGE_FILE_HEADER coff;IMAGE_DOS_HEADER dos;IMAGE_OPTIONAL_HEADER64 optional={0};
 size_t start=0;int kind=1;WORD magic;memcpy(&magic,bytes,sizeof magic);
 if(magic==IMAGE_DOS_SIGNATURE){memcpy(&dos,bytes,sizeof dos);start=(size_t)dos.e_lfanew+sizeof(DWORD);kind=2;}
 memcpy(&coff,bytes+start,sizeof coff);
 if(kind==2)memcpy(&optional,bytes+start+sizeof coff,sizeof optional);
 size_t table=start+sizeof coff+coff.SizeOfOptionalHeader;
 uint32_t strings=0,string_bytes=0;
 if(coff.PointerToSymbolTable){strings=coff.PointerToSymbolTable+coff.NumberOfSymbols*IMAGE_SIZEOF_SYMBOL;memcpy(&string_bytes,bytes+strings,4);}
 printf("layout\t%d\t%llu\t%u\t%lu\t%lu\t%u\t%u\t%llu\t%lu\n",kind,(unsigned long long)table,coff.NumberOfSections,coff.PointerToSymbolTable,coff.NumberOfSymbols,strings,string_bytes,(unsigned long long)optional.ImageBase,optional.SizeOfImage);
 for(unsigned i=0;i<coff.NumberOfSections;++i){IMAGE_SECTION_HEADER s;memcpy(&s,bytes+table+i*sizeof s,sizeof s);uint64_t name;memcpy(&name,s.Name,8);uint32_t initialized=s.PointerToRawData?s.SizeOfRawData:0;uint32_t relocations=s.PointerToRelocations,count=s.NumberOfRelocations;
  if(kind==2 && initialized>s.Misc.VirtualSize)initialized=s.Misc.VirtualSize;
  if(kind==1 && (s.Characteristics&IMAGE_SCN_LNK_NRELOC_OVFL)){IMAGE_RELOCATION first;memcpy(&first,bytes+relocations,sizeof first);count=first.RelocCount-1;relocations+=sizeof first;}
  printf("section\t%u\t%llu\t%lu\t%lu\t%lu\t%lu\t%u\t%u\t%u\t%lu\n",i,(unsigned long long)name,s.Misc.VirtualSize,s.VirtualAddress,s.PointerToRawData,s.SizeOfRawData,initialized,relocations,count,s.Characteristics);
 }
 for(unsigned i=0;i<coff.NumberOfSections;++i){IMAGE_SECTION_HEADER s;memcpy(&s,bytes+table+i*sizeof s,sizeof s);printf("name\t%u\t",i);
  if(s.Name[0]=='/'){char decimal[9]={0};memcpy(decimal,s.Name,8);const unsigned char* name=bytes+strings+strtoul(decimal+1,NULL,10);print_bytes(name,strlen((const char*)name));}else{print_bytes(s.Name,short_length(s.Name));}putchar('\n');
  uint32_t count=s.NumberOfRelocations,first=s.PointerToRelocations;if(s.Characteristics&IMAGE_SCN_LNK_NRELOC_OVFL){IMAGE_RELOCATION r;memcpy(&r,bytes+first,sizeof r);count=r.RelocCount-1;first+=sizeof r;}
  uint64_t digest=14695981039346656037ULL;for(uint32_t j=0;j<count;++j){IMAGE_RELOCATION r;memcpy(&r,bytes+first+j*sizeof r,sizeof r);const uint64_t values[]={r.VirtualAddress,r.SymbolTableIndex,r.Type};for(int k=0;k<3;++k){digest^=values[k];digest*=1099511628211ULL;}}
  printf("relocations\t%u\t%u\t%llu\n",i,count,(unsigned long long)digest);
 }
 for(uint32_t i=0;i<coff.NumberOfSymbols;){IMAGE_SYMBOL s;memcpy(&s,bytes+coff.PointerToSymbolTable+i*IMAGE_SIZEOF_SYMBOL,IMAGE_SIZEOF_SYMBOL);printf("symbol\t%u\t",i);
  if(s.N.Name.Short==0){const unsigned char* name=bytes+strings+s.N.Name.Long;print_bytes(name,strlen((const char*)name));}else{print_bytes(s.N.ShortName,short_length(s.N.ShortName));}
  uint32_t next=i+1+s.NumberOfAuxSymbols;printf("\t%lu\t%d\t%u\t%u\t%u\t%u\n",s.Value,s.SectionNumber,s.Type,s.StorageClass,s.NumberOfAuxSymbols,next);i=next;
 }
 free(bytes);return 0;
}
