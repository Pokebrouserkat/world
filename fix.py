import os
import subprocess

def commit(message):
    subprocess.run(["git", "add", "-A"], check=True)
    subprocess.run(["git", "commit", "-m", message], check=True)

def format_file_list(files):
    """Format a list of files into a human-readable string."""
    if not files:
        return ""
    if len(files) == 1:
        return files[0]
    return ", ".join(files[:-1]) + " and " + files[-1]

tofix = []
for root, dirs, files in os.walk("."):  
    # Skip .git, .github, and .godot directories
    if ".git" in dirs:
        dirs.remove(".git")
    if ".github" in dirs:
        dirs.remove(".github")
    if ".godot" in dirs:
        dirs.remove(".godot")
    for f in files:
        if f.endswith((".gd", ".tscn", ".tres", ".cfg", ".md", ".yml", ".yaml", ".html", ".sh")) or f in [".gitignore", ".editorconfig"]:
            tofix.append(os.path.join(root, f))

endfixes = []
dedents = []
tabspaces = []
nolines = []

for file in tofix:
    with open(file, "r") as f:
        data = f.read()
    if "\r" in data:
        data = data.replace("\r", "")
        with open(file, "w") as f:
            f.write(data)
        commit("Fixed line endings in " + file)
        endfixes.append(file)
    if "\t" in data:
        data = data.replace("\t", "    ")
        with open(file, "w") as f:
            f.write(data)
        commit("Replaced tabs with spaces in " + file)
        tabspaces.append(file)
    if " \n" in data:
        while " \n" in data:
            data = data.replace(" \n", "\n")
        with open(file, "w") as f:
            f.write(data)
        commit("Dedented empty lines in " + file)
        dedents.append(file)
    if data.endswith("\n"):
        data = data.rstrip()
        with open(file, "w") as f:
            f.write(data)
        commit("Removed trailing {newline|space}(s) in " + file)
        nolines.append(file)

# Print summary
messages = []
if endfixes:
    messages.append(f"fixed line endings in {format_file_list(endfixes)}")
if tabspaces:
    messages.append(f"replaced tabs with spaces in {format_file_list(tabspaces)}")
if dedents:
    messages.append(f"dedented empty lines in {format_file_list(dedents)}")
if nolines:
    messages.append(f"removed trailing newlines/spaces in {format_file_list(nolines)}")

if messages:
    print(", ".join(messages).capitalize() + ".")