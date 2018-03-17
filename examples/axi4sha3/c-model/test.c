#include <stdint.h>
#include <inttypes.h>
#include "sponge.h"

int main() {
  uint8_t phrase[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 0};
  uint8_t* expected = sponge(phrase, 10);
}
