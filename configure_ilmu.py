"""Select ILMU and save its API key locally without echoing the key."""
from getpass import getpass
from pathlib import Path
import re


def main():
    model = input("ILMU model [ilmu-nemo-nano]: ").strip() or "ilmu-nemo-nano"
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9.\-]{0,99}", model):
        raise SystemExit("Invalid model name. No settings were changed.")
    key = getpass("ILMU API key (hidden): ").strip()
    if len(key) < 20 or any(character.isspace() for character in key) or any(c in key for c in "'\"#$"):
        raise SystemExit("Invalid key format. No settings were changed.")
    path = Path(__file__).resolve().parent / "backend" / ".env"
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    names = {"AI_PROVIDER", "ILMU_API_KEY", "ILMU_MODEL"}
    lines = [line for line in lines if line.split("=", 1)[0].strip() not in names]
    lines.extend(["AI_PROVIDER=ilmu", "ILMU_API_KEY=" + key, "ILMU_MODEL=" + model])
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("ILMU selected and key saved locally. Restart the backend to apply.")


if __name__ == "__main__":
    main()
