/* Independent synthetic expression trees for the predefined native cost families.
   These formulas describe source grouping, not production node order or storage.
   Include after graph_equal; construction/comparison stays outside observations. */

/* Appends a logical expected node and joins at most two already-built roots. */
static int32_t expression_expected_node(struct syntax_node* nodes,int32_t* count,
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

/* Compares complete kinds, child topology and original spans, iteratively.
   A flat chain's tree can be much taller than the permitted source nesting. */
static int parser_expression_shape(void* published,const char* family,int32_t size,
                                   int32_t bytes,int32_t source_id) {
    if(size<0||size>16384)return 0;
    size_t maximum=(size_t)size*24+8;
    struct syntax_node* nodes=calloc(maximum,sizeof *nodes);
    int32_t* names=calloc((size_t)size*11+1,sizeof *names);
    if(!nodes||!names){free(nodes);free(names);return 0;}
    int32_t count=0,root_node=-1;
    if(strcmp(family,"flat")==0){
        for(int32_t i=0;i<size;++i){
            int32_t leaf=expression_expected_node(nodes,&count,1,2*i,2*i+1,-1,-1);
            root_node=i?expression_expected_node(nodes,&count,12,0,2*i+1,root_node,leaf):leaf;
        }
    }else if(strcmp(family,"wide")==0){
        int32_t callee=expression_expected_node(nodes,&count,1,0,1,-1,-1);
        root_node=expression_expected_node(nodes,&count,38,0,bytes,callee,-1);
        int32_t tail=callee;
        for(int32_t i=0;i<size;++i){
            int32_t leaf=expression_expected_node(nodes,&count,1,2+2*i,3+2*i,-1,-1);
            nodes[tail].next_sibling=leaf;tail=leaf;++nodes[root_node].children;
        }
    }else if(strcmp(family,"groups")==0||strcmp(family,"prefix")==0){
        root_node=expression_expected_node(nodes,&count,1,size,size+1,-1,-1);
        bool groups=strcmp(family,"groups")==0;
        for(int32_t i=size-1;i>=0;--i)
            root_node=expression_expected_node(nodes,&count,groups?3:5,i,
                                               groups?2*size+1-i:size+1,root_node,-1);
    }else if(strcmp(family,"power")==0){
        for(int32_t i=0;i<=size;++i)
            names[i]=expression_expected_node(nodes,&count,1,4*i,4*i+1,-1,-1);
        root_node=names[size];
        for(int32_t i=size-1;i>=0;--i)
            root_node=expression_expected_node(nodes,&count,7,4*i,4*size+1,names[i],root_node);
    }else if(strcmp(family,"mixed")==0){
        /* Eleven successively tighter operators lead into each open group.
           Offsets are handwritten against the fixed 56-byte source prefix. */
        static const int32_t offsets[]={0,6,12,18,23,29,33,37,41,45,49};
        static const int32_t kinds[]={30,29,28,26,24,15,14,12,8,10,11};
        for(int32_t level=0;level<size;++level)
            for(int32_t j=0;j<11;++j)
                names[11*level+j]=expression_expected_node(nodes,&count,1,56*level+offsets[j],56*level+offsets[j]+1,-1,-1);
        root_node=expression_expected_node(nodes,&count,1,56*size,56*size+1,-1,-1);
        for(int32_t level=size-1;level>=0;--level){
            int32_t last=56*size+1+(size-level);
            root_node=expression_expected_node(nodes,&count,3,56*level+55,last,root_node,-1);
            for(int32_t j=10;j>=0;--j)
                root_node=expression_expected_node(nodes,&count,kinds[j],56*level+offsets[j],last,names[11*level+j],root_node);
        }
    }
    struct parser_case expected={.name=family,.bytes=bytes,.nodes=nodes,.count=count,.root=root_node};
    int equal=root_node>=0&&count>0&&(size_t)count<=maximum&&graph_equal(published,&expected,source_id);
    free(nodes);free(names);return equal;
}

/* Exact first offending spans for the shared 256 source-depth boundary. */
static int parser_expression_depth_failure(const char* family,int32_t size,
                                          const struct syntax_failure* failure) {
    if(size!=257||failure->kind!=2)return 0;
    int32_t first=256;
    if(strcmp(family,"power")==0)first=1026;
    else if(strcmp(family,"groups")!=0&&strcmp(family,"prefix")!=0)return 0;
    return failure->first==first&&failure->last==first+1;
}
