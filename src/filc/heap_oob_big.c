#include <stdlib.h>

// EXPECT: panic
int main(void) {
  volatile char *p = (char*)malloc(1);
  p[4096] = 7;   // definitely out of the object
  return 0;
}
