#include <stdlib.h>

// EXPECT: panic
int main(void) {
  volatile char *p = (char*)malloc(8);
  volatile char x = p[-1]; // OOB read below base
  (void)x;
  return 0;
}
