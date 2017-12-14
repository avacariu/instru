import os
from setuptools import setup, find_packages, Extension
from Cython.Build import cythonize

extensions = [
    Extension('*', ['src/instrumenter/*.pyx'],
              extra_compile_args=['-O0', '-Wall']),
]


setup(
    name='instrumenter',
    version='0.1.0',
    python_requires='>=3.6',

    packages=find_packages(where='src'),
    package_dir={'': 'src'},

    ext_modules=cythonize(extensions,
                          compiler_directives={
                              'language_level': 3,
                          }),
)
