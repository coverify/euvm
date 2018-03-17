#include <stdio.h>
#include <stdint.h>
#include <inttypes.h>
#include <stdlib.h>
#include <string.h>
#include "sponge.h"

uint8_t *padding(uint8_t*,int32_t*);

const uint64_t r[5][5]={ {0,36,3,41,18},
			{1,44,10,45,2},
			{62,6,43,15,61},
			{28,55,25,21,56},
			{27,20,39,8,14}
};

int mod (int a, int b)
{
  if(b < 0) //you can check for b == 0 separately and do what you want
    return mod(-a, -b);
  int ret = a % b;
  if(ret < 0)
    ret+=b;
  return ret;
}

uint64_t **sha3_round(uint64_t **A, uint64_t RC){
  uint64_t C[5];
  uint64_t D[5];
  uint64_t B[5][5];

  /* Theta step */
  for(uint8_t x=0;x<5;x++){
    C[x]=A[x][0] ^ A[x][1] ^ A[x][2]^ A[x][3] ^ A[x][4];
  }
  for(uint8_t x=0;x<5;x++){
    D[x]=C[(x + 4) % 5] ^ ((C[(x + 1) % 5] << 1) | (C[(x + 1) % 5] >> 63));
  }
  for(uint8_t x=0;x<5;x++){
    for(uint8_t y=0;y<5;y++){
      A[x][y]=A[x][y]^D[x];
    }
  }

  /*Rho and pi steps*/
  for(uint8_t x=0;x<5;x++){
    for(uint8_t y=0;y<5;y++){
      B[y][mod((2*x+3*y),5)]=((A[x][y] << r[x][y]) | (A[x][y] >> (64-r[x][y])));
    }
  }

  /*Xi state*/
  for(uint8_t x=0;x<5;x++){
    for(uint8_t y=0;y<5;y++){
      A[x][y]=B[x][y]^((~B[mod((x+1),5)][y]) & B[mod((x+2),5)][y]);
    }
  }

  /*Last step*/
  A[0][0]=A[0][0]^RC;

  return A;
}
