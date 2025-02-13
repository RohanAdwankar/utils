use std::env;
use std::fs;
use std::io::{self, BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::process::Command;

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    let mut include_dots = false;
    let mut summary_mode = false;
    let mut directory = ".".to_string();

    for arg in &args[1..] {
        if arg == "-a" {
            include_dots = true;
        } else if arg == "-s" {
            summary_mode = true;
        } else {
            directory = arg.clone();
        }
    }

    let target_dir = Path::new(&directory);
    if !target_dir.is_dir() {
        eprintln!("Error: '{}' is not a directory.", directory);
        std::process::exit(1);
    }

    let git_ignore = target_dir.join(".git").exists();
    if git_ignore {
        println!(
            "Note: '{}' is a Git repository. Obeying .gitignore rules.",
            directory
        );
    }

    println!(
        "{}",
        target_dir
            .file_name()
            .unwrap_or_else(|| target_dir.as_os_str())
            .to_string_lossy()
    );
    print_tree(target_dir, "", include_dots, git_ignore, target_dir)?;

    println!("\n----- File Contents -----\n");
    cat_files(target_dir, include_dots, git_ignore, target_dir, summary_mode)?;

    Ok(())
}

fn print_tree(
    dir: &Path,
    prefix: &str,
    include_dots: bool,
    git_ignore: bool,
    target_dir: &Path,
) -> io::Result<()> {
    let mut entries: Vec<PathBuf> = vec![];

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
        entries.push(path);
    }

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
        println!(
            "{}{}{}",
            prefix,
            branch,
            entry.file_name().unwrap().to_string_lossy()
        );
        if entry.is_dir() {
            let new_prefix = if is_last {
                format!("{}    ", prefix)
            } else {
                format!("{}│   ", prefix)
            };
            print_tree(entry, &new_prefix, include_dots, git_ignore, target_dir)?;
        }
    }
    Ok(())
}

/// Recursively "cats" the files (prints their contents).
/// In summary mode, only the first 10 lines are printed.
/// If a file isn't valid UTF-8 (or is binary), a message is printed instead.
/// Additionally, if the file name is Cargo.lock or package-lock.json, its contents are skipped.
fn cat_files(
    dir: &Path,
    include_dots: bool,
    git_ignore: bool,
    target_dir: &Path,
    summary: bool,
) -> io::Result<()> {
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
            println!("----- {} -----", rel_path.to_string_lossy());
            if name == "Cargo.lock" || name == "package-lock.json" {
                println!("(File contents skipped)");
            } else if summary {
                let file = fs::File::open(&path)?;
                let reader = BufReader::new(file);
                let mut printed = 0;
                for line in reader.lines() {
                    if printed >= 10 {
                        println!("...");
                        break;
                    }
                    match line {
                        Ok(l) => {
                            println!("{}", l);
                            printed += 1;
                        }
                        Err(_) => {
                            println!("(Binary file, not printed)");
                            break;
                        }
                    }
                }
            } else {
                match fs::read_to_string(&path) {
                    Ok(contents) => println!("{}", contents),
                    Err(_) => println!("(Binary file, not printed)"),
                }
            }
            println!();
        } else if path.is_dir() {
            cat_files(&path, include_dots, git_ignore, target_dir, summary)?;
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
