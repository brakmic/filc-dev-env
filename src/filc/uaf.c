#include <stdlib.h>

// EXPECT: panic
int main(void) {
  volatile int *p = (int*)malloc(8);
  free((void*)p);
  *p = 1;   // use-after-free
  return 0;
}
