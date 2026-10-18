// EXPECT: panic
int main(void) {
    // Fil-C rounds allocations up to 16 bytes. Index 8 (offset 32)
    // is safely beyond the rounded stack object.
    volatile int a[1];
    a[8] = 42;
    return 0;
}
