import os
import re
import shutil
import sys
from pathlib import Path

DOWNLOADS = Path(r"C:\Users\yizha\Downloads")

CATEGORY_MAP = {
    "מסמכים":       {"pdf", "docx", "doc", "txt", "pages", "rtf"},
    "גיליונות":     {"xlsx", "xls", "csv"},
    "תמונות":       {"png", "jpg", "jpeg", "svg", "psd", "webp", "gif", "bmp", "tiff"},
    "מצגות":        {"pptx", "ppt"},
    "וידאו ומדיה":  {"mp4", "webm", "m4a", "srt", "mov", "avi"},
    "קבצי אינטרנט": {"html", "htm", "css", "js", "winmd"},
    "לוח שנה":      {"ics"},
}
TRASH_EXTENSIONS = {"exe", "msix"}
DUPLICATE_PATTERN = re.compile(r"^(.+?) \((\d+)\)$")

# Folders that already exist and should not be touched
EXISTING_SUBDIRS = None  # populated at runtime


def ext(path: Path) -> str:
    return path.suffix.lstrip(".").lower()


def category_for(path: Path) -> str:
    e = ext(path)
    for cat, extensions in CATEGORY_MAP.items():
        if e in extensions:
            return cat
    return "שונות"


def safe_dest(dest_folder: Path, filename: str) -> Path:
    dest = dest_folder / filename
    if not dest.exists():
        return dest
    stem = Path(filename).stem
    suffix = Path(filename).suffix
    counter = 1
    while True:
        candidate = dest_folder / f"{stem}_moved{counter}{suffix}"
        if not candidate.exists():
            return candidate
        counter += 1


def move(src: Path, dest_folder: Path, log: list):
    dest_folder.mkdir(parents=True, exist_ok=True)
    dest = safe_dest(dest_folder, src.name)
    shutil.move(str(src), str(dest))
    log.append(f"  הועבר: {src.name}  →  {dest_folder.name}/")


def send_to_recycle(path: Path, log: list):
    try:
        import send2trash
        send2trash.send2trash(str(path))
        log.append(f"  נשלח לסל המחזור: {path.name}")
    except ImportError:
        trash_dir = DOWNLOADS / "להסרה"
        trash_dir.mkdir(exist_ok=True)
        dest = safe_dest(trash_dir, path.name)
        shutil.move(str(path), str(dest))
        log.append(f"  הועבר ל'להסרה' (send2trash לא מותקן): {path.name}")


def is_duplicate(stem: str) -> bool:
    return bool(DUPLICATE_PATTERN.match(stem))


def main():
    global EXISTING_SUBDIRS
    log = []
    stats = {"כפילויות": 0, "מחוקים": 0, "מסווגים": 0, "שגיאות": 0}

    # Collect names of folders that existed BEFORE we start (so we don't touch them)
    EXISTING_SUBDIRS = {
        item.name for item in DOWNLOADS.iterdir() if item.is_dir()
    }
    print(f"תיקיות קיימות שיישארו ללא שינוי: {EXISTING_SUBDIRS}\n")

    # Collect only root-level files (not inside existing subdirs)
    root_files = [
        item for item in DOWNLOADS.iterdir()
        if item.is_file()
    ]

    print(f"נמצאו {len(root_files)} קבצים לטיפול\n")
    print("=" * 60)

    for f in sorted(root_files):
        stem = f.stem
        e = ext(f)

        # 1. Trash executables
        if e in TRASH_EXTENSIONS:
            try:
                send_to_recycle(f, log)
                stats["מחוקים"] += 1
            except Exception as err:
                log.append(f"  שגיאה ({f.name}): {err}")
                stats["שגיאות"] += 1
            continue

        # 2. Duplicates — any file matching "name (N).ext"
        if is_duplicate(stem):
            try:
                move(f, DOWNLOADS / "כפילויות", log)
                stats["כפילויות"] += 1
            except Exception as err:
                log.append(f"  שגיאה ({f.name}): {err}")
                stats["שגיאות"] += 1
            continue

        # 3. Categorise by extension
        cat = category_for(f)
        try:
            move(f, DOWNLOADS / cat, log)
            stats["מסווגים"] += 1
        except Exception as err:
            log.append(f"  שגיאה ({f.name}): {err}")
            stats["שגיאות"] += 1

    # Print full log
    for line in log:
        print(line)

    print("\n" + "=" * 60)
    print("סיכום:")
    print(f"  קבצים מסווגים לתיקיות:  {stats['מסווגים']}")
    print(f"  כפילויות שהועברו:        {stats['כפילויות']}")
    print(f"  קבצי EXE שנשלחו לסל:    {stats['מחוקים']}")
    print(f"  שגיאות:                  {stats['שגיאות']}")
    print("=" * 60)
    print("\nהארגון הושלם!")


if __name__ == "__main__":
    main()
