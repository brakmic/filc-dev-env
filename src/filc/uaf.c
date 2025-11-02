#include <stdlib.h>
int main() {
  volatile int *p = (int*)malloc(8);
  free((void*)p);
  *p = 1;   // UAF
}
