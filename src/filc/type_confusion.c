#include <stdlib.h>

// EXPECT: panic
struct small {
    int value;
};

struct large {
    int values[16];
};

int main(void) {
    // Reinterpreting a small object as a larger type makes the
    // access at values[8] (offset 32) leave the rounded allocation.
    volatile struct small *small = (struct small *)malloc(sizeof(struct small));
    volatile struct large *large = (struct large *)small;
    large->values[8] = 42;
    return 0;
}
