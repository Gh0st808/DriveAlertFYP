"""Save a Gemini API key to the backend's ignored .env without echoing it."""
from getpass import getpass
from pathlib import Path


def main():
    key = getpass("Gemini API key (hidden): ").strip()
    if len(key) < 20 or any(character.isspace() for character in key) or any(c in key for c in "'\"#"):
        raise SystemExit("Invalid key format. No settings were changed.")
    path = Path(__file__).resolve().parent / "backend" / ".env"
    lines = path.read_text(encoding="utf-8").splitlines() if path.exists() else []
    lines = [line for line in lines if line.split("=", 1)[0].strip() not in {"GEMINI_API_KEY", "AI_PROVIDER"}]
    lines.append("AI_PROVIDER=gemini")
    lines.append("GEMINI_API_KEY=" + key)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("Gemini key saved locally. Restart the backend, then open AI Assistant in the dashboard.")


if __name__ == "__main__":
    main()
