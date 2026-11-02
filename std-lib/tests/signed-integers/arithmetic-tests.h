static int arithmetic_cases(void){
 for(size_t index=0;index<sizeof cases/sizeof cases[0];++index){
  const struct arithmetic_case* expected=cases+index;int operation=expected->operation+1;int64_t minimum=INT64_MIN,maximum=INT64_MAX;
  if(expected->operation>=6){operation=7;if(expected->operation==6){minimum=INT32_MIN;maximum=INT32_MAX;}if(expected->operation==7){minimum=INT16_MIN;maximum=INT16_MAX;}if(expected->operation==8){minimum=0;maximum=UINT8_MAX;}}
  int32_t wanted=expected->error==77?0:(expected->error==11?4:3);
  for(int32_t seed=7;seed<=77;seed+=70){int64_t value=71;int32_t failure=5;ube_err_set(seed,"previous","signed integer logical outcome");
#ifdef NUMERIC_OBSERVED
   numeric_start();
#endif
   int ok=numeric_evaluate(operation,expected->left,expected->right,minimum,maximum,&value,&failure);
#ifdef NUMERIC_OBSERVED
   CHECK(numeric_stop(0,1,8)==0);
#endif
   int64_t expected_value=wanted==0?expected->value:71;
#ifdef NEGATIVE_NUMERIC_VALUE
   if(index==0)expected_value=1;
#endif
   CHECK(ok==(wanted==0)&&failure==wanted&&value==expected_value&&error_preserved(seed,"previous","signed integer logical outcome")==0);
  }
 }
 struct operation_case {int operation;int64_t left,right,minimum,maximum,value;int32_t failure;};
 static const struct operation_case extra[]={
  {8,0,0,INT64_MIN,INT64_MAX,-1,0},{8,-1,0,INT64_MIN,INT64_MAX,0,0},
  {8,INT64_MIN,0,INT64_MIN,INT64_MAX,INT64_MAX,0},{8,INT64_MAX,0,INT64_MIN,INT64_MAX,INT64_MIN,0},
  {9,INT64_MIN,INT64_MAX,INT64_MIN,INT64_MAX,0,0},{10,INT64_MIN,INT64_MAX,INT64_MIN,INT64_MAX,-1,0},
  {11,INT64_MIN,INT64_MAX,INT64_MIN,INT64_MAX,-1,0},{12,INT64_MIN,INT64_MAX,INT64_MIN,INT64_MAX,0,0},
  {9,-1,INT64_MAX,INT64_MIN,INT64_MAX,INT64_MAX,0},{13,0,0,INT64_MIN,INT64_MAX,-1,0},{13,-1,0,INT64_MIN,INT64_MAX,0,0},
  {9,7,3,INT64_MIN,INT64_MAX,3,0},{10,7,3,INT64_MIN,INT64_MAX,7,0},{11,7,3,INT64_MIN,INT64_MAX,4,0},
  {12,7,3,INT64_MIN,INT64_MAX,-5,0},{13,7,3,INT64_MIN,INT64_MAX,-5,0},
  {8,32767,0,-32768,32767,-32768,0},{8,-32768,0,-32768,32767,32767,0},{11,-32768,32767,-32768,32767,-1,0},
  {8,255,0,0,255,71,3},{9,128,255,0,255,128,0},{10,128,1,0,255,129,0},
  {7,200,INT64_MIN,0,255,200,0},{6,1,INT64_MAX,-32768,32767,-1,0},
  {1,40000,-10000,INT32_MIN,INT32_MAX,30000,0},{2,40000,10000,INT32_MIN,INT32_MAX,30000,0},
  {7,30000,0,-32768,32767,30000,0},{1,2147483647,1,INT32_MIN,INT32_MAX,71,3},
  {1,2147483647,1,INT64_MIN,INT64_MAX,INT64_C(2147483648),0},
  {1,32767,1,-32768,32767,71,3},{3,-32768,-1,-32768,32767,71,3},
  {3,-32768,1,-32768,32767,-32768,0},{4,-32768,-1,-32768,32767,71,3},
  {5,-32768,-1,-32768,32767,0,0},{6,-32768,0,-32768,32767,71,3},
  {1,0,0,0,0,0,0},{3,0,0,0,0,0,0},{4,0,0,0,0,71,4},
  {0,0,0,INT64_MIN,INT64_MAX,71,1},{14,0,0,INT64_MIN,INT64_MAX,71,1},
  {1,1,1,1,10,71,1},{1,-1,-1,-10,-1,71,1},
  {1,256,0,0,255,71,3},{1,0,256,0,255,71,3}
 };
 for(size_t index=0;index<sizeof extra/sizeof extra[0];++index){const struct operation_case* expected=extra+index;int64_t value=71;int32_t failure=5;ube_err_set(77,"previous","signed integer operator");
#ifdef NUMERIC_OBSERVED
  numeric_start();
#endif
  int ok=numeric_evaluate(expected->operation,expected->left,expected->right,expected->minimum,expected->maximum,&value,&failure);
#ifdef NUMERIC_OBSERVED
  CHECK(numeric_stop(0,1,8)==0);
#endif
  CHECK(ok==(expected->failure==0)&&failure==expected->failure&&value==expected->value&&error_preserved(77,"previous","signed integer operator")==0);}
 const int64_t ordered[]={INT64_MIN,INT64_C(-9223372036854775807),INT64_C(-2147483649),INT32_MIN,-32768,-1,0,1,255,32767,INT32_MAX,INT64_C(2147483648),INT64_MAX};
 for(size_t left=0;left<sizeof ordered/sizeof ordered[0];++left)for(size_t right=0;right<sizeof ordered/sizeof ordered[0];++right){int32_t expected=left<right?-1:(left>right?1:0);
#ifdef NUMERIC_OBSERVED
  numeric_start();
#endif
  int32_t actual=numeric_compare(ordered[left],ordered[right]);
#ifdef NUMERIC_OBSERVED
  CHECK(numeric_stop(0,1,1)==0);
#endif
  CHECK(actual==expected&&error_preserved(77,"previous","signed integer operator")==0);}
 printf("{\"suite\":\"arithmetic\",\"passed\":true,\"reusedBoundaryCases\":%zu,\"staleErrSeeds\":2,\"additionalCases\":%zu,\"comparisonPairs\":169}\n",sizeof cases/sizeof cases[0],sizeof extra/sizeof extra[0]);return 0;
}
