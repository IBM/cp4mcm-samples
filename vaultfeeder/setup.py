import setuptools
setuptools.setup(
    name='vaultfeeder',
    version='0.0.1',
    url='https://github.com/IBM/cp4mcm-samples/vaultfeeder',
    entry_points={
        'console_scripts': ['vaultfeeder=vaultfeeder.vaultfeeder:main']
    },
    author='Shrinath Thube',
    author_email="shrinaththube@gmail.com",
    description='This script is to configure HashiCorp valut for IBM Multicloud Management VM policies controller and many more functionality',
    packages=setuptools.find_packages(include=['vaultfeeder.*']),
    install_requires=[], 
    python_requires='>=3.6'
)