import amfpack
import unittest

TESTS_VARINT = {
    0: b'\x00',
    0x35: b'\x35',
    0x7f: b'\x7f',
    0x80: b'\x81\x00',
    0xd4: b'\x81\x54',
    0x3fff: b'\xff\x7f',
    0x4000: b'\x81\x80\x00',
    0x1a53f: b'\x86\xca\x3f',
    0x1fffff: b'\xff\xff\x7f',
    0x200000: b'\x80\xc0\x80\x00',
    -0x01: b'\xff\xff\xff\xff',
    -0x2a: b'\xff\xff\xff\xd6',
    0xfffffff: b'\xbf\xff\xff\xff',
    -0x10000000: b'\xc0\x80\x80\x00'
}

TESTS_STRING = {
    '': b'\x01',
    'hello': b'\x0bhello',
    'ᚠᛇᚻ': b'\x13\xe1\x9a\xa0\xe1\x9b\x87\xe1\x9a\xbb'
}

TESTS_DOUBLE = {
    0.1: b'\x3f\xb9\x99\x99\x99\x99\x99\x9a',
    0.123456789: b'\x3f\xbf\x9a\xdd\x37\x39\x63\x5f'
}


class TestEncoder(unittest.TestCase):
    def test_integer(self):
        for integer, encoding in TESTS_VARINT.items():
            encoder = amfpack.Encoder()
            encoder.add_integer(integer)
            self.assertEqual(encoding, encoder.bytes()[1:])

    def test_double(self):
        for double, encoding in TESTS_DOUBLE.items():
            encoder = amfpack.Encoder()
            encoder.add_double(double)
            self.assertEqual(encoding, encoder.bytes()[1:])

    def test_array(self):
        encoded = b'\x09\x09\x01'  # array header
        encoded += b'\x04\x00'  # array element 1
        encoded += b'\x04\x01'  # array element 2
        encoded += b'\x04\x02'  # array element 3
        encoded += b'\x04\x03'  # array element 4

        encoder = amfpack.Encoder()
        encoder.add_array(dense_container=[0, 1, 2, 3])
        self.assertEqual(encoded, encoder.bytes())