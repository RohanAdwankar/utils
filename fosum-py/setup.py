from setuptools import setup, find_packages

setup(
    name="fosum",
    version="0.5.0",
    description="A simple tool that summarizes file folders. Useful for passing context to LLMs",
    author="Rohan Adwankar",
    author_email="rohan.adwankar@gmail.com",
    license="MIT",
    packages=find_packages(),
    include_package_data=True,
    package_data={
        "fosum": ["bin/fosum"],
    },
    entry_points={
        "console_scripts": [
            "fosum = fosum:run_fosum",
        ],
    },
)
