# Random Utility Scripts

These are some random utility scripts I use to build faster.

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

## treecat.rs
Generates a summary of the folder.
It generates a tree diagram of the directory.
It also displays all the files in the directory.

## install.sh
Sets up rust,js scripts and saves it as an alias.
### Example
```
./install.sh treecat.rs
```