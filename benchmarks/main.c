#include <stdint.h>

#include "sha2.h"

int main(void) {
    uint64_t retc = 0;
    
    retc = benchmark_sha256();
    if (retc != 0) return retc;

    return 0;
}
