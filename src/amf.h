#ifndef AMF_H
#define AMF_H

#include "amf_types.h"
#include <stdint.h>

int deserialize_varint(unsigned char* data, unsigned int* value);
int deserialize_signed_varint(unsigned char* data, int* value);
int deserialize_utf8_header(unsigned char* data, unsigned int* index, unsigned int* length, int* bytes_read);
int deserialize_utf8(unsigned char* data, unsigned int* index, unsigned char* str, unsigned int* length, int* bytes_read);
void deserialize_double(unsigned char* data, double* value);
int deserialize_reference(unsigned char* data, unsigned int* index);

void little_endian_to_big_endian(unsigned int value, unsigned char *output) {
    output[0] = (value >> 24) & 0xFF;
    output[1] = (value >> 16) & 0xFF;
    output[2] = (value >> 8) & 0xFF;
    output[3] = value & 0xFF;
}

void double_to_big_endian(double x, unsigned char *buf) {
    unsigned char *p = (unsigned char *)&x; // treat x as a byte array
    int i;
    for (i = 0; i < sizeof(double); i++) {
        buf[sizeof(double)-1-i] = *p++; // reverse the byte order
    }
}

unsigned int as_varint(int value);

#endif
