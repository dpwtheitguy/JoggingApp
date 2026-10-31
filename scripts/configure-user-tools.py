"""Install shell environment and desktop launcher without replacing user settings."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
home = Path.home()
config = home / ".config/runprogram"
config.mkdir(parents=True, exist_ok=True)
shutil.copyfile(root / "scripts/dev-env.sh", config / "dev-env.sh")
rc = home / ".bashrc"
line = '\n# RUN//PROGRAM Android and Flutter tools\n[ ! -f "$HOME/.config/runprogram/dev-env.sh" ] || . "$HOME/.config/runprogram/dev-env.sh"\n'
existing = rc.read_text() if rc.exists() else ""
if '"$HOME/.config/runprogram/dev-env.sh"' not in existing:
    with rc.open("a") as handle:
        handle.write(line)
apps = home / ".local/share/applications"
apps.mkdir(parents=True, exist_ok=True)
studio = home / "Development/android-studio"
(apps / "runprogram-android-studio.desktop").write_text(
    "[Desktop Entry]\nType=Application\nName=Android Studio\n"
    f'Exec="{studio}/bin/studio.sh" %f\n'
    f"Icon={studio}/bin/studio.svg\n"
    "Terminal=false\nCategories=Development;IDE;\nStartupNotify=true\n"
)
print("Configured bash environment and Android Studio desktop launcher.")
