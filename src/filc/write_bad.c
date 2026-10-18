#include <unistd.h>

// EXPECT: panic
int main(void) {
    char *q = (char*)0x1;
    return (int)write(1, q, 1);
}
