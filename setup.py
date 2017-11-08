from setuptools import setup, find_packages
from Cython.Build import cythonize


setup(
    name='instrumenter',
    version='0.1.0',
    python_requires='>=3.6',

    packages=find_packages(where='src'),
    package_dir={'': 'src'},

    ext_modules=cythonize('src/instrumenter/*.pyx',
                          compiler_directives={
                              'language_level': 3,
                          }),
)
