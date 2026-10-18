#include <stdlib.h>

// EXPECT: panic
int main(void) {
  // malloc(4) is rounded up to a 16-byte object. Index 8 (offset 32)
  // is outside the rounded allocation.
  volatile int *p = (int*)malloc(sizeof(int));
  p[8] = 42;
  return 0;
}
