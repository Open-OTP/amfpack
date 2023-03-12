#ifndef AMF_TYPE_H
#define AMF_TYPE_H

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
#define MB 1048576


typedef enum {
    t_undefined = 0x00,
    t_null = 0x01,
    t_false = 0x02,
    t_true = 0x03,
    t_integer = 0x04,
    t_double = 0x05,
    t_string = 0x06,
    t_xml_doc = 0x07,
    t_date = 0x08,
    t_array = 0x09,
    t_object = 0x0A,
    t_xml = 0x0B,
    t_byte_array = 0x0C,
    t_vector_int = 0x0D,
    t_vector_uint = 0x0E,
    t_vector_double = 0x0F,
    t_vector_object = 0x10,
    t_dictionary = 0x11,
} AMFType;


#endif