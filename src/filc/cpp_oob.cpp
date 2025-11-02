#include <iostream>
#include <vector>
#include <memory>

class Buffer {
public:
    Buffer(size_t size) : data(new int[size]), size(size) {}
    ~Buffer() { delete[] data; }
    
    volatile int* get() { return data; }
    
private:
    volatile int* data;
    size_t size;
};

void demonstrate_oob() {
    std::cout << "Testing C++ with memory safety violations..." << std::endl;
    
    Buffer buffer(10);
    volatile int* ptr = buffer.get();
    
    std::cout << "Writing out of bounds at offset 4096..." << std::endl;
    ptr[4096] = 42;
    
    std::cout << "This line should never execute!" << std::endl;
}

int main() {
    demonstrate_oob();
    return 0;
}
