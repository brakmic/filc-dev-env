#include <unistd.h>

int main() { 
    char *q = (char*)0x1; 
    return (int)write(1, q, 1); 
}
