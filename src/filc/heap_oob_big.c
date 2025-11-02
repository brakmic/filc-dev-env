#include <stdlib.h>
int main() {
  volatile char *p = (char*)malloc(1);
  p[4096] = 7;   // definitely out of the object
}
