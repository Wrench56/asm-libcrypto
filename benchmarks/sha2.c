#include <immintrin.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <sodium.h>

#include "sha2.h"

#include <openssl/evp.h>
#include <openssl/rand.h>

#include <bearssl.h>


#define BUFFER_SIZE 13000
#define ITERATIONS 100000


static inline double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return (double) ts.tv_sec + 1e-9 * (double) ts.tv_nsec;
}

static void print_hash(const uint8_t *hash) {
    printf("Hash: ");
    for (size_t i = 0; i < 32; i++) {
        printf("%02x", hash[i]);
    }

    printf("\n");
}

static void benchmark_openssl(unsigned char buffer[]) {
    unsigned char hash[32];
    double start = now_sec();

    unsigned int outl = 0;
    const EVP_MD* md = EVP_sha256();
    EVP_MD_CTX* mdctx = EVP_MD_CTX_new();

    for (int i = 0; i < ITERATIONS; i++) {
        EVP_DigestInit_ex(mdctx, md, NULL);
        EVP_DigestUpdate(mdctx, buffer, BUFFER_SIZE);
        EVP_DigestFinal_ex(mdctx, hash, &outl);
    }

    EVP_MD_CTX_free(mdctx);

    double end = now_sec();
    double elapsed = end - start;
    printf("OpenSSL SHA-256:       %.2f hashes/sec\n", ITERATIONS / elapsed);
    print_hash(hash);
}

static void benchmark_libsodium(unsigned char buffer[]) {
    uint8_t hash[32];

    double start = now_sec();

    if (sodium_init() < 0) return;
    for (int i = 0; i < ITERATIONS; i++) {
        crypto_hash_sha256(hash, buffer, BUFFER_SIZE);
    }

    double end = now_sec();
    double elapsed = end - start;
    printf("Libsodium SHA-256:     %.2f hashes/sec\n", ITERATIONS / elapsed);
    print_hash(hash);
}

static void benchmark_bearssl(unsigned char buffer[]) {
    uint8_t hash[32];

    double start = now_sec();

    br_sha256_context ctx;
    for (int i = 0; i < ITERATIONS; i++) {
        br_sha256_init(&ctx);
        br_sha256_update(&ctx, buffer, BUFFER_SIZE);
    }

    br_sha256_out(&ctx, hash);

    double end = now_sec();
    double elapsed = end - start;
    printf("BearSSL SHA-256:       %.2f hashes/sec\n", ITERATIONS / elapsed);
    print_hash(hash);
}

static void benchmark_asm_sha256(unsigned char buffer[]) {
    uint8_t hash[32];

    double start = now_sec();
    for (int i = 0; i < ITERATIONS; i++) {
        libcrypto_sha256(buffer, BUFFER_SIZE, hash);
    }

    double end = now_sec();
    double elapsed = end - start;
    printf("asm-libcrypto SHA-256: %.2f hashes/sec\n", ITERATIONS / elapsed);
    print_hash(hash);
}

int benchmark_sha256(void) {
    printf("Benchmarking SHA-256 (%d iterations, %d-byte buffer)...\n\n", ITERATIONS, BUFFER_SIZE);

    unsigned char* buffer = malloc(BUFFER_SIZE);
    if (buffer == NULL) {
        return 1;
    }

    if (RAND_bytes(buffer, BUFFER_SIZE) != 1) {
        return 2;
    }

    /* Prefetch buffer to cache */
#if BUFFER_SIZE < (32 * 1024 * 1024 * 1024)
    for (uint64_t off = 0; off < BUFFER_SIZE; off += 64) {
#if BUFFER_SIZE < (16 * 1024 * 1024)
        _mm_prefetch(buffer + off, _MM_HINT_T0);
#elif BUFFER_SIZE < (256 * 1024 * 1024)
        _mm_prefetch(buffer + off, _MM_HINT_T1);
#else
        _mm_prefetch(buffer + off, _MM_HINT_T2);
#endif
    }
#endif

    benchmark_libsodium(buffer);
    benchmark_asm_sha256(buffer);
    benchmark_openssl(buffer);
    benchmark_bearssl(buffer);
    printf("\n");

    free(buffer);
    return 0;
}

__attribute__((weak)) int main(void) {
    return benchmark_sha256();
}
