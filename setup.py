from setuptools.extension import Extension

from setuptools import setup, find_packages
from Cython.Build import cythonize

amf_ext = Extension(
    name='amfpack.amf',
    sources=['src/amf.c', 'amfpack/amf.pyx'],
    include_dirs=['src'],
)


setup(
    name='amfpack',
    version='0.1',
    ext_modules=cythonize(amf_ext, compiler_directives={'language_level': '3'},),
    author='alexanderr',
    url='https://www.github.com/Open-OTP/amfpack',
    packages = find_packages(),
    requires=['Cython'],
)
