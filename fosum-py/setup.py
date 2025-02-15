from setuptools import setup, find_packages
import pathlib

here = pathlib.Path(__file__).parent.resolve()
long_description = (here / "README.md").read_text(encoding="utf-8")

setup(
    name="fosum",
    version="0.6.0",
    description="A simple tool that summarizes file folders. Useful for passing context to LLMs.",
    long_description=long_description,
    long_description_content_type="text/markdown",
    author="Rohan Adwankar",
    author_email="rohan.adwankar@gmail.com",
    license="MIT",
    url="https://github.com/RohanAdwankar/utils",
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