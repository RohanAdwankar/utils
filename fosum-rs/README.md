# fosum: folder summary tool

Tool for summarizing a folder.
Useful for passing context of a repo to an LLM.
Default behavior copies summary to clipboard and outputs nothing.
Supports options:  
- **-a**: include dot files/folders
- **-s**: summary mode (first 10 lines per file)
- **-l**: list output to stdout
- **-t**: tree-only mode (prints just a tree diagram of the repo)

```
cargo install fosum
fosum
```