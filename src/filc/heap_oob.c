#include <stdlib.h>
int main() {
  volatile int *p = (int*)malloc(sizeof(int)); // 4 bytes
  p[2] = 42;                                   // write 8 bytes past end
}
