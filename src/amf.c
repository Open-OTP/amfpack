#include "amf_types.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

#define U29_FLAG ((unsigned int)(1 << 28))


unsigned int as_varint(int value, int* num_bytes) {
    value &= 0x1fffffff;
    unsigned int temp = value;
    int n = 1;

    if(value <= (unsigned int)0x7F) {
        value = value & 0x7F;
    }
    else if(value <= (unsigned int)0x3FFF) {
        value = temp & 0x7F;
        value |= (temp & 0x3F80) << 1;
        value |= (1 << 15);
        n = 2;
    }
    else if(value <= (unsigned int)0x1FFFFF) {
        value = temp & 0x7F;
        value |= (temp & 0x3F80) << 1;
        value |= (temp & 0x1FC000) << 2;
        value |= (1 << 15) | (1 << 23);
        n = 3;
    }
    else {
        value = temp & 0x7FFF;
        value |= (temp & 0x3F8000) << 1;
        value |= (temp & 0x1FC00000) << 2;
        value |= (1 << 15) | (1 << 23) | (1 << 31);
        n = 4;
    }

    *num_bytes = n;

    return value;
}



int deserialize_varint(unsigned char* data, unsigned int* value) {
    unsigned int temp = 0;
    int num_bytes = 1;
    char byte = data[0];

    // If 0x80 is set, int includes the next byte, up to 4 total bytes
    while ((byte & 0x80) && (num_bytes < 4)) {
        temp <<= 7;
        temp |= byte & 0x7F;
        byte = data[num_bytes];
        num_bytes++;
    }

    if (num_bytes < 4) {
        temp <<= 7; // shift by 7, since the 1st bit is reserved for next byte flag
        temp |= byte & 0x7F;
    } else {
        temp <<= 8; // shift by 8, since no further bytes are possible and 1st bit is not used for flag.
        temp |= byte & 0xFF;
    }

    *value = temp;
    return num_bytes;
}

int deserialize_signed_varint(unsigned char* data, int* value){
    int num_bytes = deserialize_varint(data, (unsigned int *)value);

    // Move sign bit, since we're converting 29bit->32bit
    if (*value & 0x10000000) {
        *value -= 0x20000000;
    }

    return num_bytes;
}


int deserialize_utf8_header(unsigned char* data, unsigned int* index, unsigned int* length, int* num_header_bytes) {
    unsigned int header;

    *num_header_bytes = deserialize_varint(data, &header);

    *index = 0;
    *length = 0;

    if(header == 0x01){ // empty string
        return 2;
    }

    int is_string_ref = (header & 0x01) == 0;

    *length = header >> 1;

    if(is_string_ref){
        // index
        *index = (*length ^ U29_FLAG);
    }

    return is_string_ref;
}


int deserialize_utf8(unsigned char* data, unsigned int* index, unsigned char** str, unsigned int* length, int* bytes_read) {
    int header_result = deserialize_utf8_header(data, index, length, bytes_read);
    unsigned int _length = *length;

    *str = NULL;

    if(header_result == 2){
        // empty string
        return 0;
    }
    else if(header_result == 0) {
        *str = malloc(_length + 1);
        (*str)[_length] = '\0';
        // string literal
        memcpy(*str, data + *bytes_read, _length);
        *bytes_read = *bytes_read + _length;
        return 0;
    }
    else {
        // string reference
        return 1;
    }
}


void deserialize_double(unsigned char* data, double* value) {
    uint64_t val = 0;
    memcpy(&val, data, sizeof(uint64_t));
    val = ((val & 0xff00000000000000ull) >> 56) |
          ((val & 0x00ff000000000000ull) >> 40) |
          ((val & 0x0000ff0000000000ull) >> 24) |
          ((val & 0x000000ff00000000ull) >> 8) |
          ((val & 0x00000000ff000000ull) << 8) |
          ((val & 0x0000000000ff0000ull) << 24) |
          ((val & 0x000000000000ff00ull) << 40) |
          ((val & 0x00000000000000ffull) << 56);
    *value = *((double*)&val);
}

int deserialize_reference(unsigned char* data, unsigned int* index) {
    unsigned int header;

    int num_header_bytes = deserialize_varint(data, &header);
    int is_reference = (header & 0x01) == 0;
    *index = ((header >> 1) ^ U29_FLAG);
    return is_reference;
}

