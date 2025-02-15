use std::env;
use std::fs;
use std::io::{BufRead, BufReader, Write as IoWrite};
use std::fmt::Write; // for String's write_fmt method
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Usage: treecat [-a] [-s] [-l] [-t] [directory]
    //   -a: include dot files/folders (default: false)
    //   -s: summary mode (print only the first 10 lines per file)
    //   -l: list output to stdout (default: copy output to clipboard)
    //   -t: tree only mode (display only the directory tree and print to stdout)
    //   directory: target directory (default: ".")
    let args: Vec<String> = env::args().collect();
    let mut include_dots = false;
    let mut summary_mode = false;
    let mut list_output = false; // if true, print to stdout; if false, copy to clipboard (default)
    let mut tree_only = false;
    let mut directory = ".".to_string();

    for arg in &args[1..] {
        match arg.as_str() {
            "-a" => include_dots = true,
            "-s" => summary_mode = true,
            "-l" => list_output = true,
            "-t" => tree_only = true,
            _ => directory = arg.clone(),
        }
    }

    let target_dir = Path::new(&directory);
    if !target_dir.is_dir() {
        eprintln!("Error: '{}' is not a directory.", directory);
        std::process::exit(1);
    }

    let git_ignore = target_dir.join(".git").exists();
    let mut output = String::new();

    // Print the tree header.
    let header = if directory == "." {
        ".".to_string()
    } else {
        target_dir
            .file_name()
            .unwrap_or_else(|| target_dir.as_os_str())
            .to_string_lossy()
            .into_owned()
    };
    writeln!(output, "{}", header)?;
    print_tree_buffer(target_dir, "", include_dots, git_ignore, target_dir, &mut output)?;

    // If not in tree only mode, print file contents.
    if !tree_only {
        cat_files_buffer(target_dir, include_dots, git_ignore, target_dir, summary_mode, &mut output)?;
    }

    // If tree only mode or -l is passed, list output to stdout; otherwise, copy to clipboard using pbcopy.
    if tree_only || list_output {
        print!("{}", output);
    } else {
        let mut child = Command::new("pbcopy")
            .stdin(Stdio::piped())
            .spawn()?;
        child.stdin.as_mut().unwrap().write_all(output.as_bytes())?;
    }

    Ok(())
}

/// Recursively writes a tree-like structure of the directory into `out`.
fn print_tree_buffer(
    dir: &Path,
    prefix: &str,
    include_dots: bool,
    git_ignore: bool,
    target_dir: &Path,
    out: &mut String,
) -> Result<(), Box<dyn std::error::Error>> {
    let mut entries: Vec<PathBuf> = vec![];

    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().into_owned();

        // Skip special entries and (unless requested) dot files/folders.
        if name == "." || name == ".." || (!include_dots && name.starts_with('.')) {
            continue;
        }
        if git_ignore && is_git_ignored(&path, target_dir) {
            continue;
        }
        entries.push(path);
    }

    // Sort entries alphabetically.
    entries.sort_by(|a, b| {
        a.file_name()
            .unwrap()
            .to_string_lossy()
            .cmp(&b.file_name().unwrap().to_string_lossy())
    });

    let total = entries.len();
    for (i, entry) in entries.iter().enumerate() {
        let is_last = i == total - 1;
        let branch = if is_last { "└── " } else { "├── " };
        writeln!(
            out,
            "{}{}{}",
            prefix,
            branch,
            entry.file_name().unwrap().to_string_lossy()
        )?;
        if entry.is_dir() {
            let new_prefix = if is_last {
                format!("{}    ", prefix)
            } else {
                format!("{}│   ", prefix)
            };
            print_tree_buffer(entry, &new_prefix, include_dots, git_ignore, target_dir, out)?;
        }
    }
    Ok(())
}

/// Recursively "cats" the files (prints their contents) into `out`.
/// - In summary mode, only the first 10 lines of each file are printed.
/// - If a file is binary or not valid UTF-8, a placeholder message is printed.
/// - For files named Cargo.lock or package-lock.json, the contents are skipped.
/// - Each file’s content is preceded by a custom header.
fn cat_files_buffer(
    dir: &Path,
    include_dots: bool,
    git_ignore: bool,
    target_dir: &Path,
    summary: bool,
    out: &mut String,
) -> Result<(), Box<dyn std::error::Error>> {
    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().into_owned();

        if name == "." || name == ".." || (!include_dots && name.starts_with('.')) {
            continue;
        }
        if git_ignore && is_git_ignored(&path, target_dir) {
            continue;
        }

        if path.is_file() {
            let rel_path = path.strip_prefix(target_dir).unwrap_or(&path);
            writeln!(
                out,
                "/////////////////////// The following file is: {} ///////////////////////",
                rel_path.to_string_lossy()
            )?;
            if name == "Cargo.lock" || name == "package-lock.json" {
                writeln!(out, "(File contents skipped)")?;
            } else if summary {
                let file = fs::File::open(&path)?;
                let reader = BufReader::new(file);
                let mut printed = 0;
                for line in reader.lines() {
                    if printed >= 10 {
                        writeln!(out, "...")?;
                        break;
                    }
                    match line {
                        Ok(l) => {
                            writeln!(out, "{}", l)?;
                            printed += 1;
                        }
                        Err(_) => {
                            writeln!(out, "(Binary file, not printed)")?;
                            break;
                        }
                    }
                }
            } else {
                match fs::read_to_string(&path) {
                    Ok(contents) => writeln!(out, "{}", contents)?,
                    Err(_) => writeln!(out, "(Binary file, not printed)")?,
                }
            }
            writeln!(out)?;
        } else if path.is_dir() {
            cat_files_buffer(&path, include_dots, git_ignore, target_dir, summary, out)?;
        }
    }
    Ok(())
}

/// Uses `git check-ignore` to see if a file/directory should be ignored.
fn is_git_ignored(path: &Path, target_dir: &Path) -> bool {
    let output = Command::new("git")
        .arg("-C")
        .arg(target_dir)
        .arg("check-ignore")
        .arg(path)
        .output();

    if let Ok(output) = output {
        output.status.success()
    } else {
        false
    }
}