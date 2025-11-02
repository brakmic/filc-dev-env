#include <stdlib.h>
int main() {
  volatile char *p = (char*)malloc(8);
  volatile char x = p[-1]; // OOB read below base
}
