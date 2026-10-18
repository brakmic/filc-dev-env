#include <stdlib.h>

// EXPECT: panic
int main(void) {
    volatile void *p = malloc(8);
    free((void *)p);
    free((void *)p);  // double free
    return 0;
}
