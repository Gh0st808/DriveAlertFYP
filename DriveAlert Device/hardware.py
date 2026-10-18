"""Lazy camera, landmark and audio adapters; API can start even if hardware is unavailable."""
import os
import time
from pathlib import Path

class Camera:
    def __init__(self):
        import cv2
        self.cv2 = cv2
        self.camera = None
        self.picamera = None
        mode = os.getenv("CAMERA_BACKEND", "picamera2")
        if mode == "picamera2":
            from picamera2 import Picamera2
            self.picamera = Picamera2()
            try:
                self.picamera.configure(self.picamera.create_video_configuration(
                    main={"size": (640, 480), "format": "RGB888"}, controls={"FrameRate": 30}))
                self.picamera.start()
            except Exception:
                self.picamera.close()
                raise
        else:
            self.camera = cv2.VideoCapture(int(os.getenv("CAMERA_INDEX", "0")))
            self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            self.camera.set(cv2.CAP_PROP_FPS, 30)
            if not self.camera.isOpened():
                self.camera.release()
                raise RuntimeError("Cannot open camera. Check CAMERA_BACKEND and the camera cable.")

    def read(self):
        if self.picamera is not None:
            return self.picamera.capture_array()
        success, frame = self.camera.read()
        if not success:
            raise RuntimeError("Camera stopped returning frames.")
        return frame

    def close(self):
        if self.picamera is not None:
            self.picamera.stop()
            self.picamera.close()
        elif self.camera is not None:
            self.camera.release()


class Landmarks:
    def __init__(self):
        import mediapipe as mp
        self.mp = mp
        model = Path(os.getenv("FACE_MODEL", str(Path(__file__).with_name("face_landmarker.task"))))
        if not model.is_file():
            raise RuntimeError("face_landmarker.task is missing. Run download_model.py first.")
        options = mp.tasks.vision.FaceLandmarkerOptions(
            base_options=mp.tasks.BaseOptions(model_asset_path=str(model)),
            running_mode=mp.tasks.vision.RunningMode.VIDEO, num_faces=1)
        self.detector = mp.tasks.vision.FaceLandmarker.create_from_options(options)
        self.last_timestamp = 0

    def find(self, bgr):
        import cv2
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        image = self.mp.Image(image_format=self.mp.ImageFormat.SRGB, data=rgb)
        timestamp = max(self.last_timestamp + 1, int(time.monotonic() * 1000))
        self.last_timestamp = timestamp
        result = self.detector.detect_for_video(image, timestamp)
        if not result.face_landmarks:
            return None
        height, width = bgr.shape[:2]
        return [(p.x * width, p.y * height) for p in result.face_landmarks[0]]

    def close(self):
        self.detector.close()


class Audio:
    def __init__(self):
        self.mixer = None
        try:
            import pygame
            pygame.mixer.init()
            self.mixer = pygame.mixer
        except Exception as error:
            print("[AUDIO] Unavailable:", error, flush=True)

    def play(self, name):
        if self.mixer:
            try:
                self.mixer.music.load(str(Path(__file__).with_name(name)))
                self.mixer.music.play()
            except Exception as error:
                print("[AUDIO]", error, flush=True)

    def close(self):
        if self.mixer:
            self.mixer.quit()

