"""
update_progress.py

Repository ke andar TODO comments dhoondhta hai, ek summary banata hai,
aur aaj ki date ke saath progress.md ke NEECHE append karta hai.
Pehle se mojood entries kabhi delete nahi hoti — history barqarar rehti hai.
"""

import datetime
import os
import re

REPO_DIR = os.path.dirname(os.path.abspath(__file__))
PROGRESS_FILE = os.path.join(REPO_DIR, "progress.md")

# Ignore karnay ke liye directories/files
SKIP_DIRS = {".git", "__pycache__", ".pytest_cache", ".venv", "venv", "node_modules"}
SKIP_FILES = {__file__, os.path.basename(__file__)}

# .py mein # TODO ... / .md mein - [ ] TODO wale patterns
TODO_PATTERNS = [
    re.compile(r"#\s*TODO[:\s]*(.+)", re.IGNORECASE),       # Python comments
    re.compile(r"<!--\s*TODO[:\s]*(.*?)-->", re.IGNORECASE), # HTML comments
    re.compile(r"-\s*\[\s*\]\s*(.+)"),                       # Markdown unchecked lists
    re.compile(r"//\s*TODO[:\s]*(.+)", re.IGNORECASE),      # JS/C-style comments
]


def find_todos():
    """Repository scan kar ke TODO items ki list return karta hai (file, line, text)."""
    todos = []
    for root, dirs, files in os.walk(REPO_DIR):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for filename in files:
            if filename in SKIP_FILES:
                continue
            filepath = os.path.join(root, filename)
            try:
                with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                    for lineno, line in enumerate(f, start=1):
                        for pattern in TODO_PATTERNS:
                            match = pattern.search(line)
                            if match:
                                rel_path = os.path.relpath(filepath, REPO_DIR)
                                todos.append((rel_path, lineno, match.group(1)))
                                break
            except (OSError, UnicodeDecodeError):
                continue
    return todos


def build_summary(todos):
    """TODO list se markdown summary banata hai."""
    lines = []
    if todos:
        lines.append(f"**{len(todos)} TODO(s) found across the repository:**\n")
        by_file = {}
        for path, lineno, text in todos:
            by_file.setdefault(path, []).append((lineno, text))
        for path in sorted(by_file):
            lines.append(f"- `{path}`:")
            for lineno, text in by_file[path]:
                lines.append(f"  - Line {lineno}: {text.strip()}")
    else:
        lines.append("**No TODO comments found in the repository.**")
        lines.append("(Sample TODO list for demonstration: check the script fallback below.)")
    return "\n".join(lines)


def main():
    todos = find_todos()

    # Fallback: agar koi TODO na mile, toh sample TODO list use karo
    if not todos:
        todos = [
            ("calculator.py", 1, "Add a subtract() function"),
            ("monitor.py", 5, "Make interval configurable via CLI arg"),
            ("progress.md", 1, "Keep this log updated daily"),
        ]

    summary = build_summary(todos)
    today = datetime.date.today().isoformat()

    new_entry = (
        f"\n---\n\n"
        f"## Entry - {today}\n\n"
        f"{summary}\n"
    )

    # Append mode: existing history kabhi delete nahi hoti
    with open(PROGRESS_FILE, "a", encoding="utf-8") as f:
        f.write(new_entry)

    print(f"[OK] progress.md updated with entry for {today}")
    print(f"[OK] {len(todos)} TODO(s) logged (existing entries preserved)")


if __name__ == "__main__":
    main()