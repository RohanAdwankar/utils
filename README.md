# Random Utility Scripts

These are some random utility scripts I use to build faster.

## fosum
Tool for summarizing a folder.
Useful for passing context of a repo to an LLM.
Default behavior copies summary to clipboard and outputs nothing.
Supports options:  
- **-a**: include dot files/folders
- **-s**: summary mode (first 10 lines per file)
- **-l**: list output to stdout
- **-t**: tree-only mode (prints just a tree diagram of the rpo)
  
Running:
```
npm install -g fosum OR pip install fosum OR cargo install fosum
fosum
```


Rust: ![Crates.io Downloads (latest version)](https://img.shields.io/crates/dv/fosum)   JavaScript: ![NPM Downloads](https://img.shields.io/npm/dw/fosum)   Python: [![PyPI Downloads](https://static.pepy.tech/badge/fosum)](https://pepy.tech/projects/fosum)


## compress_video.sh
Uses ffmpeg to compress a video to a desired file size. Useful for when macOS screen recordings are too large for sharing.

### Basic Usage
```bash
./compress_video.sh input_file target_size_mb
```

### Convert MOV to MP4 During Compression
```bash
./compress_video.sh input_file target_size_mb mp4
```

## genDir.js

A Node.js script to automatically generate directory structures from a text-based tree representation. Useful for directory creation when using an AI tool like Claude etc. which tend to output these trees.

## Usage

```bash
node genDir.js <structure-file-path> [output-path]
```

Where:
- `<structure-file-path>`: Path to the structure definition file (required)
- `[output-path]`: Optional destination directory (defaults to current directory)

## Example

Given a file `structure.txt`:
```
my-project/
├── src/
│   ├── index.js
│   └── utils.js
└── test/
    └── index.test.js
```

Running:
```bash
node genDir.js structure.txt
```

Will create the intuitive directory.

## install.sh
Sets up rust,js scripts and saves it as an alias.
### Example
```
./install.sh treecat.rs
```

## size.sh
Script for when your computer is out of memory to find typically useless stuff.

## speed.sh
Script for when you need to make a video a specific time. It will speed it up to achieve that time.