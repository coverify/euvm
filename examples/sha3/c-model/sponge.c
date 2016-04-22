#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>
#include "round.h"
#include "sponge.h"
#include "keccak_f.h"

uint8_t *sponge(uint8_t* M,int32_t size){
  int32_t r=72;
  int32_t w=8;
  /*Padding*/
  if((size%r)!=0){//r=72 bytes
    M=padding(M,&size);
  }
  uint64_t *nM;
  nM=(uint64_t *)M;
  /*Initialization*/
  uint64_t **S=(uint64_t **)calloc(5,sizeof(uint64_t*));
  for(uint64_t i = 0; i < 5; i++) S[i] = (uint64_t *)calloc(5,sizeof(uint64_t));
  /*Absorbing Phase*/
  for(int32_t i=0;i<size/r;i++){//Each block has 72 bytes
    for(int32_t y=0;y<5;y++){
      for(int32_t x=0;x<5;x++){
	if((x+5*y)<(r/w)){
	  S[x][y]=S[x][y] ^ *(nM+i*9+x+5*y);
	  //	  S=keccak_f(S);
	}
      }
    }
    S=keccak_f(S);
  }
  /*Squeezing phase*/
  int32_t b=0;
  uint64_t *Z=(uint64_t *)calloc(8,sizeof(uint64_t));
  while(b<8) {
    for(int32_t y=0;y<5;y++){
      for(int32_t x=0;x<5;x++){
	if((x+5*y) < (r/w) - 1) {
	  *(Z+b) ^= S[x][y];
	  b++;
	}
      }
    }
  }
  return (uint8_t *) Z;
}

uint8_t *padding(uint8_t* M, int32_t* S){
  int32_t i=*S;
  int32_t newS=(*S+72-(*S%72));;
  uint8_t *nM;
  nM=malloc(*S+(72-(*S%72)));
  /*Copy string*/
  for(int32_t j=0;j<*S;j++){
    *(nM+j)=*(M+j);
  }
  *(nM+i)=0x01;
  i++;
  while(i<(newS-1)){
    *(nM+i)=0x00;
    i++;
  }
  *(nM+i)=0x80;
  i++;
  *S=i;
  return nM;
}
