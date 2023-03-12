from libc.stdlib cimport malloc, realloc, free
from libc.string cimport memcpy

cpdef enum AMFType:
    t_undefined = 0x00
    t_null = 0x01
    t_false = 0x02
    t_true = 0x03
    t_integer = 0x04
    t_double = 0x05
    t_string = 0x06
    t_xml_doc = 0x07
    t_date = 0x08
    t_array = 0x09
    t_object = 0x0A
    t_xml = 0x0B
    t_byte_array = 0x0C
    t_vector_int = 0x0D
    t_vector_uint = 0x0E
    t_vector_double = 0x0F
    t_vector_object = 0x10
    t_dictionary = 0x11


cdef extern from "amf.h":
    int deserialize_varint(const unsigned char* data, unsigned int* value)
    int deserialize_signed_varint(const unsigned char* data, int* value)
    int deserialize_utf8(unsigned char* data, unsigned int* index, unsigned char** s, unsigned int* length, int* bytes_read)
    void deserialize_double(unsigned char * data, double * value)

    unsigned int as_varint(int value, int* num_bytes)

    void little_endian_to_big_endian(unsigned int value, unsigned char *output)
    void double_to_big_endian(double x, unsigned char *buf)


def get_varint(const unsigned char[:] buff):
    cdef unsigned int x
    deserialize_varint(&buff[0], &x)
    return x


def get_signed_varint(const unsigned char[:] buff):
    cdef int x
    deserialize_signed_varint(&buff[0], &x)
    return x


def get_string(const unsigned char[:] buff):
    cdef unsigned int index
    cdef unsigned int length
    cdef int bytes_read
    cdef unsigned char* s
    cdef int is_string_reference = deserialize_utf8(&buff[0], &index, &s, &length, &bytes_read)
    if is_string_reference:
        print('is string ref')
        return index
    elif s == NULL:
        return ''
    else:
        return (<bytes>s).decode('utf-8')



UNDEFINED = object()



cdef class AMFClassDef:
    cdef object name
    cdef object static_members
    def __init__(self):
        self.name = ''
        self.static_members = {}

cdef class AMFObject(AMFClassDef):
    cdef object dynamic_members
    def __init__(self):
        AMFClassDef.__init__(self)
        self.dynamic_members = {}


cdef class AMFArray:
    cdef object _arr
    cdef object _map
    def __init__(self, arr, attr_map):
        self._arr: list = arr
        self._map: dict = attr_map

    @property
    def dense(self):
        return self._arr

    @property
    def associative(self):
        return self._map

    def __len__(self):
        return len(self._arr) + len(self._map)

    def __iter__(self):
        yield from self._arr
        yield from self._map

    def __getitem__(self, item):
        if isinstance(item, int):
            return self._arr[item]
        else:
            return self._map[item]


cdef class Decoder:
    cdef unsigned char* _start
    cdef unsigned char* _ptr
    cdef int length
    cdef object string_refs
    cdef object object_refs
    cdef object traits_refs

    def __cinit__(self):
        self._ptr = NULL
        self._start = NULL
        self.length = 0
    def __init__(self, const unsigned char[:] data):
        self._start = self._ptr = &data[0]
        self.length = data.shape[0]

        self.string_refs = {}
        self.object_refs = {}
        self.traits_refs = {}

    cpdef read_data_type(self):
        cdef char obj_type = self._ptr[0]
        self._ptr += 1

        if obj_type == t_undefined:
            return UNDEFINED
        elif obj_type == t_null:
            return None
        elif obj_type == t_false:
            return False
        elif obj_type == t_true:
            return True
        elif obj_type == t_integer:
            return self.read_integer()
        elif obj_type == t_double:
            return self.read_double()
        elif obj_type == t_string:
            return self.read_string().decode('UTF-8')
        elif obj_type == t_xml_doc:
            raise NotImplementedError
        elif obj_type == t_date:
            return self.read_date()
        elif obj_type == t_array:
            return self.read_array()
        elif obj_type == t_object:
            return self.read_object()
        elif obj_type == t_xml:
            raise NotImplementedError
        elif obj_type == t_byte_array:
            return self.read_byte_array()
        elif obj_type == t_vector_int:
            pass
        elif obj_type == t_vector_uint:
            pass
        elif obj_type == t_vector_double:
            pass
        elif obj_type == t_vector_object:
            pass
        elif obj_type == t_dictionary:
            pass

    cdef read_integer(self):
        cdef int value
        self._ptr += deserialize_signed_varint(self._ptr, &value)
        return value

    cdef read_double(self):
        cdef double value
        deserialize_double(self._ptr, &value)
        self._ptr += sizeof(double)
        return value

    cdef read_string(self):
        cdef unsigned int index
        cdef unsigned int length
        cdef int bytes_read
        cdef unsigned char * s
        cdef int is_string_reference = deserialize_utf8(self._ptr, &index, &s, &length, &bytes_read)
        self._ptr += bytes_read

        if is_string_reference:
            return self.string_refs[index]
        elif s == NULL:
            return b''
        n = len(self.string_refs)
        byte_obj = <bytes>s
        self.string_refs[n] = byte_obj
        free(s)
        return byte_obj

    cdef read_date(self):
        cdef unsigned int header
        cdef unsigned int index
        cdef double timestamp_ms

        self._ptr += deserialize_varint(self._ptr, &header)
        if (header & 0x01) == 0:
            index = header >> 1
            return self.object_refs[index]
        else:
            return self.read_double()

    cdef read_array(self):
        cdef unsigned int header
        cdef unsigned int index
        cdef unsigned int num_dense_items


        self._ptr += deserialize_varint(self._ptr, &header)
        if (header & 0x01) == 0:
            index = header >> 1
            return self.object_refs[index]
        else:
            num_dense_items = header >> 1
            arr = [None] * num_dense_items
            attr_map = {}

            key = self.read_string()
            while key != b'':
                attr_map[key] = self.read_data_type()
                key = self.read_string()

            for i in range(num_dense_items):
                arr[i] = self.read_data_type()

            return AMFArray(arr, attr_map)


    cdef read_class_def(self, unsigned int header):
        cdef int is_dynamic = header & 0x08
        cdef int num_static_attrs = header >> 4

        object_def = AMFObject()
        object_def.name = self.read_string()

        static_attrs = [None] * num_static_attrs

        for i in range(num_static_attrs):
            static_attrs[i] = self.read_string()

        static_members = object_def.static_members

        for i in range(num_static_attrs):
            static_members[static_attrs[i]] = self.read_data_type()

        dynamic_members = object_def.dynamic_members

        if is_dynamic:
            dynamic_name = None
            while dynamic_name != b'':
                dynamic_name = self.read_string()
                value = self.read_data_type()
                dynamic_members[dynamic_name] = value

        n = len(self.object_refs)
        self.object_refs[n] = object_def
        return object_def

    cdef read_ext_class_def(self):
        class_name = self.read_string()
        raise Exception('Unhandled externalizable type: %s' % class_name)

    cdef read_object(self):
        cdef unsigned int header
        cdef unsigned int index

        self._ptr += deserialize_varint(self._ptr, &header)

        if (header & 0x01) == 0:
            # U29O-ref
            # Object reference
            index = header >> 1
            return self.object_refs[index]
        elif (header & 0x02) == 0:
            # U29O-traits-ref
            index = header >> 2
            return self.traits_refs[index]
        elif (header & 0x04) == 0:
            # U29O-traits class-name *(UTF-8-vr)
            return self.read_class_def(header)
        else:
            # (U29O-traits-ext class-name *(U8))
            return self.read_ext_class_def()


    cdef read_byte_array(self):
        cdef unsigned int header
        cdef unsigned int index
        cdef unsigned int length
        cdef char* data

        self._ptr += deserialize_varint(self._ptr, &header)
        if (header & 0x01) == 0:
            index = header >> 1
            return self.object_refs[index]
        else:
            length = header >> 1
            data = <char *>malloc(length)
            memcpy(data, self._ptr, length)
            self._ptr += length
            data_b = <bytes>data
            free(data)
            return data_b



cdef class Encoder:
    cdef unsigned char* buffer
    cdef unsigned int length
    cdef unsigned int offset
    cdef unsigned int buffer_size

    def __init__(self, const unsigned char[:] initial_data=b''):
        if initial_data.size:
            self.append_data(&initial_data[0], initial_data.size)

    def __cinit__(self):
        self.length = 0
        self.offset = 0
        self.buffer_size = 64
        self.buffer = <unsigned char *>malloc(self.buffer_size)

    cdef void check_resize(self, const unsigned int min_size):
        if self.buffer_size >= min_size:
            return

        while self.buffer_size < min_size:
            self.buffer_size *= 2

        self.buffer = <unsigned char *>realloc(self.buffer, self.buffer_size)
        if self.buffer is NULL:
            raise MemoryError('could not allocate memory for serialization operation')

    cdef inline void append_byte(self, char value):
        cdef unsigned int new_size = max(self.offset + 1, self.length)
        self.check_resize(new_size)
        if self.buffer is NULL:
            return
        self.buffer[self.offset] = value
        self.length = new_size
        self.offset += 1

    cdef inline void append_data(self, const void* value, const unsigned int value_size):
        cdef unsigned int new_size = max(self.offset + value_size, self.length)
        self.check_resize(new_size)
        if self.buffer is NULL:
            return
        memcpy(&self.buffer[self.offset], value, value_size)
        self.length = new_size
        self.offset += value_size

    def bytes(self):
        cdef unsigned char[::1] memview = <unsigned char[:self.length:1]>self.buffer
        return bytes(memview)
    def __len__(self):
        return self.length

    def __dealloc__(self):
        if self.buffer is not NULL:
            free(self.buffer)
            self.buffer = NULL

    def seek(self, unsigned int n):
        if n < 0 or n > self.length:
            raise OverflowError('invalid pos in Datagram')
        self.offset = n

    def tell(self):
        return self.offset

    def add_undefined(self):
        self.append_byte(t_undefined)

    def add_null(self):
        self.append_byte(t_null)

    def add_false(self):
        self.append_byte(t_false)

    def add_true(self):
        self.append_byte(t_true)

    cdef _add_varint(self, const long long value):
        cdef unsigned int varint = value

        cdef int num_bytes
        varint = as_varint(<int> varint, &num_bytes)

        cdef unsigned int varint_big_endian
        little_endian_to_big_endian(varint, <unsigned char *> &varint_big_endian)
        self.append_data((<unsigned char *> &varint_big_endian) + (4 - num_bytes), num_bytes)

    def add_integer(self, const long long value):
        self.append_byte(t_integer)
        cdef unsigned int v_value
        if value >= (1 << 28) or value < -(1L << 28):
            self.add_double(float(value))
        else:
            self._add_varint(value)

    def add_double(self, double value):
        self.append_byte(t_double)
        cdef double double_big_endian
        double_to_big_endian(value, <unsigned char *> &double_big_endian)
        self.append_data(&double_big_endian, sizeof(double))

    cdef _add_utf8(self, const char* data, unsigned int length):
        if length == 0:
            # Empty string
            self._add_varint(0x01)
        else:
            self._add_varint((length << 1) | 0x01)
            self.append_data(&data, length)
    def add_string(self, value):
        self.append_byte(t_string)

        if type(value) == str:
            value = value.encode('utf-8')

        length = len(value)
        self._add_utf8(value, length)

    def add_string_ref(self, unsigned int index):
        self.append_byte(t_string)
        index <<= 1
        self.append_data(&index, sizeof(index))

    def add_date(self, double timestamp):
        self.append_byte(t_date)
        self._add_varint(0x1)
        self.append_data(&timestamp, sizeof(timestamp))

    def add_date_ref(self, unsigned int index):
        self.append_byte(t_date)
        index <<= 1
        self.append_data(&index, sizeof(index))

    def add_array(self, dense_container=None, associative_container=None):
        self.append_byte(t_array)

        if dense_container is not None:
            self._add_varint((len(dense_container) << 1) | 0x01)
        else:
            self._add_varint(1)

        if associative_container is None:
            self._add_utf8(NULL, 0)
        else:
            if type(associative_container) != dict:
                raise ValueError('unsupported container for associative_container')

            for key, value in associative_container.items():
                if type(key) == str:
                    key = key.encode('utf-8')
                elif type(key) != bytes:
                    raise NotImplementedError('Invalid key type')

                self._add_utf8(key, len(key))
                self.add(value)

        if dense_container is not None:
            for item in dense_container:
                self.add(item)

    def add_array_ref(self, unsigned int index):
        self.append_byte(t_array)
        index <<= 1
        self.append_data(&index, sizeof(index))

    def add_bytes(self, const unsigned char[:] data):
        cdef unsigned int length = data.shape[0]
        self.append_byte(t_byte_array)

        self._add_varint((length << 1) | 0x01)
        if length:
            self.append_data(&data[0], length)

    def add(self, obj):
        obj_type = type(obj)

        if obj == UNDEFINED:
            self.add_undefined()
        elif obj is None:
            self.add_null()
        elif obj_type == bool:
            self.add_true() if obj else self.add_false()
        elif obj_type == int:
            self.add_integer(obj)
        elif obj_type == float:
            self.add_double(obj)
        elif obj_type == str:
            self.add_string(obj)
        elif obj_type == list or obj_type == tuple:
            self.add_array(dense_container=obj)
        elif obj.__class__ == AMFArray:
            self.add_array(dense_container=obj.dense, associative_container=obj.associative)
        elif obj_type == dict:
            raise NotImplementedError
        elif obj_type == bytes:
            self.add_bytes(obj)
        else:
            raise NotImplementedError('Cannot add object of type: %s' % obj.__class__)
