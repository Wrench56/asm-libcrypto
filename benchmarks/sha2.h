#ifndef LIBCRYPTO_SHA2_H
#define LIBCRYPTO_SHA2_H

#include <stddef.h>
#include <stdint.h>

#define SYSV __attribute__((sysv_abi))

extern SYSV void libcrypto_sha256(const uint8_t* block, size_t length, uint8_t* digest);

int benchmark_sha256(void);

#endif // LIBCRYPTO_SHA2_H
