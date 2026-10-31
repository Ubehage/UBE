/* Independent expected trees for synthetic statement/control sources.
   Fixed source spellings and the normative grammar determine these coordinates;
   production node identity and construction order are deliberately irrelevant.
   Include after graph_equal, outside every measured parser observation. */

/* Adds a scalar logical node and connects at most two already-built children. */
static int32_t control_expected_node(struct syntax_node* nodes,int32_t* count,
                                    int32_t kind,int32_t first,int32_t last,
                                    int32_t left,int32_t right) {
    int32_t id=(*count)++;
    nodes[id]=(struct syntax_node){kind,first,last,left,-1,left>=0?1:0};
    if(right>=0){
        if(left>=0)nodes[left].next_sibling=right;
        else nodes[id].first_child=right;
        ++nodes[id].children;
    }
    return id;
}

/* Maps only the three fixed synthetic source families, never source text. */
static int control_family(const char* family,int32_t* prefix,int32_t* closing,
                          int32_t* name_offset,int32_t* kind,int32_t* keyword) {
    if(strcmp(family,"if")==0||strcmp(family,"block-if")==0){
        *prefix=10;*closing=7;*name_offset=3;*kind=68;*keyword=2;return 1;
    }
    if(strcmp(family,"while")==0||strcmp(family,"block-while")==0){
        *prefix=8;*closing=5;*name_offset=6;*kind=71;*keyword=5;return 1;
    }
    if(strcmp(family,"with")==0||strcmp(family,"block-with")==0){
        *prefix=7;*closing=9;*name_offset=5;*kind=72;*keyword=4;return 1;
    }
    return 0;
}

/* The fixed native header is48bytes; "Sub Work()\n" extends its prefix to59.
   A procedure Body preserves every original body byte, including final LF. */
static int parser_unit_lines_shape(void* published,int32_t size,int32_t bytes,
                                   int32_t source_id) {
    if(size<0||size>16384||bytes!=67+8*size)return 0;
    size_t maximum=(size_t)size*2+8;
    struct syntax_node* nodes=calloc(maximum,sizeof *nodes);
    if(!nodes)return 0;
    int32_t count=0;
    int32_t native_header=control_expected_node(nodes,&count,50,0,48,-1,-1);
    int32_t name=control_expected_node(nodes,&count,1,52,56,-1,-1);
    int32_t parameters=control_expected_node(nodes,&count,47,56,58,-1,-1);
    int32_t header=control_expected_node(nodes,&count,50,48,58,name,parameters);
    int32_t body=control_expected_node(nodes,&count,46,59,59+8*size,-1,-1);
    int32_t tail=-1;
    for(int32_t i=0;i<size;++i){
        int32_t first=59+8*i;
        name=control_expected_node(nodes,&count,1,first+6,first+7,-1,-1);
        int32_t statement=control_expected_node(nodes,&count,49,first,first+7,name,-1);
        if(tail<0)nodes[body].first_child=statement;
        else nodes[tail].next_sibling=statement;
        tail=statement;
        ++nodes[body].children;
    }
    int32_t marker=control_expected_node(nodes,&count,58,59+8*size,66+8*size,-1,-1);
    int32_t procedure=control_expected_node(nodes,&count,65,48,66+8*size,header,body);
    nodes[body].next_sibling=marker;
    ++nodes[procedure].children;
    int32_t root_node=control_expected_node(nodes,&count,45,0,bytes,native_header,procedure);
    struct parser_case expected={.name="unit-lines",.bytes=bytes,.nodes=nodes,.count=count,.root=root_node};
    int equal=count==(int32_t)maximum&&graph_equal(published,&expected,source_id);
    free(nodes);
    return equal;
}

/* Requires every exact source extent and child edge for nested controls around
   the fixed eight-byte "Print a\n" body. Each block owns its one complete child;
   control extents include their terminator and exclude its final newline. */
static int parser_control_shape(void* published,const char* family,int32_t depth,
                                int32_t bytes,int32_t source_id) {
    if(strcmp(family,"unit-lines")==0)
        return parser_unit_lines_shape(published,depth,bytes,source_id);
    if(depth<0||depth>256)return 0;
    int32_t prefix=0,closing=0,name_offset=0,kind=0,keyword=0;
    if(!control_family(family,&prefix,&closing,&name_offset,&kind,&keyword))return 0;
    if(bytes!=(prefix+closing)*depth+8)return 0;
    size_t maximum=(size_t)depth*3+2;
    struct syntax_node* nodes=calloc(maximum,sizeof *nodes);
    if(!nodes)return 0;
    int32_t count=0;
    int32_t body_start=prefix*depth;
    int32_t name=control_expected_node(nodes,&count,1,body_start+6,body_start+7,-1,-1);
    int32_t root_node=control_expected_node(nodes,&count,49,body_start,body_start+7,name,-1);
    for(int32_t level=depth-1;level>=0;--level){
        int32_t first=prefix*level;
        int32_t last=body_start+8+(depth-level)*closing-1;
        name=control_expected_node(nodes,&count,1,first+name_offset,first+name_offset+1,-1,-1);
        int32_t block=control_expected_node(nodes,&count,46,nodes[root_node].first,nodes[root_node].last,root_node,-1);
        root_node=control_expected_node(nodes,&count,kind,first,last,name,block);
    }
    struct parser_case expected={.name=family,.bytes=bytes,.nodes=nodes,.count=count,.root=root_node};
    int equal=count==(int32_t)maximum&&graph_equal(published,&expected,source_id);
    free(nodes);
    return equal;
}

/* The 257th source opener fails before consumption under the shared limit256. */
static int parser_control_depth_failure(const char* family,int32_t depth,
                                        const struct syntax_failure* failure) {
    int32_t prefix=0,closing=0,name_offset=0,kind=0,keyword=0;
    if(depth!=257||failure->kind!=2||
       !control_family(family,&prefix,&closing,&name_offset,&kind,&keyword))return 0;
    return failure->first==256*prefix&&failure->last==256*prefix+keyword;
}
