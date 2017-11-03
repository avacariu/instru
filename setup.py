from setuptools import setup, Extension, find_packages
from Cython.Build import cythonize

cythonize('src/instrumenter/cfg.pyx')
cythonize('src/instrumenter/utils.pyx')

ext_modules = [
    Extension('instrumenter.instru',
              sources=[
                  'src/instrumenter/instru.c',
                  'src/instrumenter/cfg.c',
                  'src/instrumenter/utils.c',
              ]),
]


setup(
    name='instrumenter',
    version='0.1.0',
    python_requires='>=3.6',

    packages=find_packages(where='src'),
    package_dir={'': 'src'},

    ext_modules=ext_modules,
)
