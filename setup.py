from distutils.extension import Extension

from setuptools import setup
from Cython.Build import cythonize

amf_ext = Extension(
    name='amfpack',
    sources=['src/amf.c', 'src/amfpack.pyx'],
    include_dirs=['src'],
)


setup(
    name='amfpack',
    version='0.1',
    ext_modules=cythonize(amf_ext, compiler_directives={'language_level': '3'},),
    author='alexanderr',
    url='https://www.github.com/Open-OTP/amfpack',
    packages=['amfpack'],
    requires=['Cython'],
)