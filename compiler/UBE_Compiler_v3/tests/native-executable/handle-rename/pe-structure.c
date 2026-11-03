#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <wchar.h>

static int read_at(HANDLE file, uint64_t size, uint64_t offset, unsigned char *out, DWORD count) {
    if (offset > size || count > size-offset || offset > INT64_MAX) return 0;
    LARGE_INTEGER position; position.QuadPart=(LONGLONG)offset; DWORD read=0;
    return SetFilePointerEx(file,position,NULL,FILE_BEGIN) && ReadFile(file,out,count,&read,NULL) && read==count;
}
static uint16_t u16(const unsigned char *p) { return (uint16_t)((uint16_t)p[0] | (uint16_t)((uint16_t)p[1]<<8)); }
static uint32_t u32(const unsigned char *p) { return (uint32_t)p[0] | ((uint32_t)p[1]<<8) | ((uint32_t)p[2]<<16) | ((uint32_t)p[3]<<24); }
#ifdef CHECK_IMAGE_LAYOUT
typedef struct { uint32_t address, virtual_size, raw_size; } SectionRange;
static int power_of_two(uint32_t value) { return value && !(value & (value-1)); }
static int backed(const SectionRange *sections, uint32_t count, uint32_t address, uint32_t length) {
    for (uint32_t i=0;i<count;++i) {
        const SectionRange *s=&sections[i];
        if (address<s->address) continue;
        uint64_t offset=(uint64_t)address-s->address;
        if (offset<=s->raw_size && length<=s->raw_size-offset &&
            (!s->virtual_size || (offset<=s->virtual_size && length<=s->virtual_size-offset))) return 1;
    }
    return 0;
}
#endif
int wmain(int argc, wchar_t **argv) {
    if (argc!=2) return 2;
    HANDLE file=INVALID_HANDLE_VALUE;
    if (wcscmp(argv[1],L"-")==0) {
        if (!DuplicateHandle(GetCurrentProcess(),GetStdHandle(STD_INPUT_HANDLE),GetCurrentProcess(),&file,0,FALSE,DUPLICATE_SAME_ACCESS)) file=INVALID_HANDLE_VALUE;
    } else file=CreateFileW(argv[1],GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_DELETE,NULL,OPEN_EXISTING,0,NULL);
    if (file==INVALID_HANDLE_VALUE) return 2;
    LARGE_INTEGER length; unsigned char dos[64], coff[24], opt[112], section[40]; int valid=0;
    if (!GetFileSizeEx(file,&length) || length.QuadPart<0) goto done;
    uint64_t size=(uint64_t)length.QuadPart;
    if (!read_at(file,size,0,dos,sizeof(dos)) || u16(dos)!=0x5a4d) goto done;
    uint64_t pe=u32(dos+60);
    if (!read_at(file,size,pe,coff,sizeof(coff)) || u32(coff)!=0x4550 || u16(coff+4)!=0x8664) goto done;
    uint16_t count=u16(coff+6), optional_size=u16(coff+20), flags=u16(coff+22);
    if (!count || optional_size<112 || !(flags&2) || (flags&0x2000)) goto done;
    uint64_t optional=pe+24;
    if (!read_at(file,size,optional,opt,sizeof(opt)) || u16(opt)!=0x20b) goto done;
#ifndef OMIT_DIRECTORY_BOUNDS
    if (u32(opt+108) > ((uint32_t)optional_size-112u)/8u) goto done;
#endif
    uint32_t entry=u32(opt+16), file_alignment=u32(opt+36), image_size=u32(opt+56);
#ifdef CHECK_IMAGE_LAYOUT
    SectionRange sections[96];
    uint32_t section_alignment=u32(opt+32), headers_size=u32(opt+60);
    if (pe<64 || count>96 || u32(opt+108)>16 || u16(opt+68)!=3 ||
        !power_of_two(file_alignment) || file_alignment<512 || file_alignment>65536 ||
        !power_of_two(section_alignment) || section_alignment<4096 || section_alignment<file_alignment ||
        !image_size || image_size%section_alignment || !headers_size ||
        headers_size%file_alignment || headers_size>size || headers_size>image_size) goto done;
    uint64_t virtual_end=((uint64_t)headers_size+section_alignment-1)/section_alignment*section_alignment;
    uint64_t raw_end=headers_size;
#endif
#ifndef OMIT_DIRECTORY_RANGES
    uint32_t directory_count=u32(opt+108);
    for (uint32_t i=0;i<directory_count && i<((uint32_t)optional_size-112u)/8u;++i) {
        unsigned char directory[8];
        if (!read_at(file,size,optional+112+(uint64_t)i*8,directory,sizeof(directory))) goto done;
        uint32_t address=u32(directory), length=u32(directory+4);
        if (address && length) {
#ifdef CERTIFICATE_AS_RVA
            uint64_t limit=image_size;
#else
            uint64_t limit=i==4 ? size : image_size;
#endif
            if ((uint64_t)address>limit || (uint64_t)length>limit-address) goto done;
        }
    }
#endif
#ifndef OMIT_FILE_ALIGNMENT
    if (!file_alignment || (file_alignment & (file_alignment-1))) goto done;
#else
    (void)file_alignment;
#endif
    uint64_t table=optional+optional_size, table_bytes=(uint64_t)count*40;
    if (!entry || entry>=image_size || table>size || table_bytes>size-table) goto done;
#ifdef CHECK_IMAGE_LAYOUT
    if (table>headers_size || table_bytes>headers_size-table) goto done;
#endif
    int entry_backed=0;
    for (uint32_t i=0;i<count;++i) {
        if (!read_at(file,size,table+(uint64_t)i*40,section,sizeof(section))) goto done;
        uint32_t virtual_size=u32(section+8), virtual_address=u32(section+12), raw_size=u32(section+16), raw_offset=u32(section+20), characteristics=u32(section+36);
        (void)virtual_size;
#ifdef CHECK_IMAGE_LAYOUT
        sections[i]=(SectionRange){virtual_address,virtual_size,raw_size};
        uint64_t extent=virtual_size>raw_size ? virtual_size : raw_size;
        if (extent) {
            if (virtual_address%section_alignment || virtual_address<virtual_end ||
                (uint64_t)virtual_address+extent>image_size) goto done;
            virtual_end=((uint64_t)virtual_address+extent+section_alignment-1)/section_alignment*section_alignment;
            if (virtual_end>image_size) goto done;
        }
        if (raw_size) {
            if (raw_offset<raw_end) goto done;
            raw_end=(uint64_t)raw_offset+raw_size;
        }
#endif
#ifndef OMIT_SECTION_IMAGE_START
        if ((virtual_size || raw_size) && virtual_address>=image_size) goto done;
#endif
#ifndef OMIT_SECTION_IMAGE_END
        if (virtual_size && (virtual_address>=image_size || virtual_size>image_size-virtual_address)) goto done;
#endif
#ifndef OMIT_FILE_ALIGNMENT
        if (raw_size && (raw_offset%file_alignment || raw_size%file_alignment)) goto done;
#endif
#ifndef OMIT_RAW_BOUNDS
        if (raw_size && ((uint64_t)raw_offset>size || (uint64_t)raw_size>size-raw_offset)) goto done;
#else
        (void)raw_offset;
#endif
        if ((characteristics&0x20000000u) && entry>=virtual_address && (uint64_t)entry-virtual_address<raw_size) {
#ifdef CHECK_IMAGE_LAYOUT
            if (virtual_size && (uint64_t)entry-virtual_address>=virtual_size) goto done;
#endif
            entry_backed=1;
        }
    }
#ifdef CHECK_IMAGE_LAYOUT
    for (uint32_t i=0;i<u32(opt+108);++i) {
        unsigned char directory[8];
        if (!read_at(file,size,optional+112+(uint64_t)i*8,directory,sizeof(directory))) goto done;
        uint32_t address=u32(directory), length=u32(directory+4);
        if (i==7 || i==14 || i==15) { if (address || length) goto done; continue; }
        if (!address && !length) continue;
        if (i==8) {
            if (length || !backed(sections,count,address,1)) goto done;
        } else if (!address || !length) goto done;
        else if (i==4) {
            if (address%8 || (uint64_t)address>size || length>size-(uint64_t)address) goto done;
        } else if (!backed(sections,count,address,length)) goto done;
    }
#endif
    valid=entry_backed;
done:
    CloseHandle(file); puts(valid ? "structure accepted" : "structure rejected"); return valid?0:1;
}
