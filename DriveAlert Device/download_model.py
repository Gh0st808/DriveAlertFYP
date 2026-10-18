"""Run once on a connected Pi; inference itself does not need internet."""
from pathlib import Path
from urllib.request import urlretrieve
target = Path(__file__).with_name("face_landmarker.task")
if target.exists():
    print("Keeping existing model:", target)
else:
    temporary = target.with_suffix(".download")
    urlretrieve("https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task", temporary)
    temporary.replace(target)
    print("Downloaded:", target)

