"""Check simple Markdown formatting and repository-relative links."""

import re
from pathlib import Path
from urllib.parse import urlsplit


def main() -> None:
    """Report issues in tracked documentation directories."""
    root = Path(__file__).resolve().parent.parent
    files = [
        *root.glob("*.md"),
        *(root / "docs").rglob("*.md"),
        *(root / "templates").rglob("*.md"),
    ]
    errors = []
    for path in sorted(files):
        name = path.relative_to(root)
        contents = path.read_text(encoding="utf-8")
        if not contents.endswith("\n") or contents.endswith("\n\n"):
            errors.append(f"{name}: expected exactly one final newline")
        for number, line in enumerate(contents.splitlines(), 1):
            if line != line.rstrip():
                errors.append(f"{name}:{number}: trailing whitespace")
        for link in re.findall(r"\[[^\]\n]*\]\(([^)\s]+)\)", contents):
            parsed = urlsplit(link)
            if not parsed.scheme and parsed.path and not parsed.path.startswith("/"):
                if not (path.parent / parsed.path).exists():
                    errors.append(f"{name}: missing path {parsed.path}")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"Checked formatting and local links in {len(files)} Markdown files.")


if __name__ == "__main__":
    main()
