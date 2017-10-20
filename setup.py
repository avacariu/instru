from setuptools import setup, Extension, find_packages


setup(
    name='instrumenter',
    version='0.1.0',
    python_requires='>=3.6',

    packages=find_packages(where='src'),
    package_dir={'': 'src'},

    ext_modules=[
        Extension('instrumenter.instru', ['src/instrumenter/instru.c'])
    ],
)
