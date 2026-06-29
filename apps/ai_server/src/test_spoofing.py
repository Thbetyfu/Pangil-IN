import unittest
import os
import wave
import numpy as np
from spoofing import (
    check_jpeg_exif, 
    analyze_wav_acoustics, 
    verify_image_authenticity, 
    verify_audio_authenticity
)

class TestSpoofingEngine(unittest.TestCase):
    def setUp(self):
        self.temp_files = []

    def tearDown(self):
        for f in self.temp_files:
            if os.path.exists(f):
                os.remove(f)

    def write_temp_file(self, filename: str, content: bytes) -> str:
        path = os.path.join(os.path.dirname(__file__), filename)
        with open(path, 'wb') as f:
            f.write(content)
        self.temp_files.append(path)
        return path

    def test_check_jpeg_exif_valid(self):
        # Create a mock JPEG with an APP1 marker containing the 'Exif' signature
        valid_jpeg_bytes = b'\xff\xd8\xff\xe1\x00\x08Exif\x00\x00' + b'\x00' * 100
        path = self.write_temp_file('test_valid.jpg', valid_jpeg_bytes)
        self.assertTrue(check_jpeg_exif(path))

    def test_check_jpeg_exif_missing(self):
        # Create a standard JPEG APP0 (JFIF) without APP1 EXIF
        invalid_jpeg_bytes = b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00' + b'\x00' * 100
        path = self.write_temp_file('test_no_exif.jpg', invalid_jpeg_bytes)
        self.assertFalse(check_jpeg_exif(path))

    def test_verify_image_authenticity_real_file(self):
        # Spoofed image (missing EXIF)
        invalid_jpeg_bytes = b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00'
        path = self.write_temp_file('test_no_exif.jpg', invalid_jpeg_bytes)
        
        result = verify_image_authenticity(path)
        self.assertTrue(result['is_spoofed'])
        self.assertIn("Missing camera hardware EXIF metadata", result['reasons'][0])

    def test_analyze_wav_acoustics_silence_anomaly(self):
        # Create a mock WAV file containing 50% absolute silence (zeros)
        path = os.path.join(os.path.dirname(__file__), 'test_silence.wav')
        self.temp_files.append(path)
        
        # 1000 samples: 500 zeros, 500 normal values
        samples = np.zeros(1000, dtype=np.int16)
        samples[500:] = 1000 # normal low amplitude
        
        with wave.open(path, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2) # 16-bit PCM
            w.setframerate(8000)
            w.writeframes(samples.tobytes())
            
        analysis = analyze_wav_acoustics(path)
        self.assertTrue(analysis['is_anomaly'])
        self.assertIn("synthesized digital vocoder pattern", analysis['reason'])

    def test_analyze_wav_acoustics_clipping_anomaly(self):
        # Create a mock WAV file containing clipping saturation (max int16 value)
        path = os.path.join(os.path.dirname(__file__), 'test_clipping.wav')
        self.temp_files.append(path)
        
        samples = np.full(500, 32767, dtype=np.int16) # Saturated
        
        with wave.open(path, 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(8000)
            w.writeframes(samples.tobytes())
            
        analysis = analyze_wav_acoustics(path)
        self.assertTrue(analysis['is_anomaly'])
        self.assertIn("clipping / saturation artifacts", analysis['reason'])

    def test_verify_audio_authenticity_mock_fallback(self):
        # URL mock verification with deepfake keyword
        result = verify_audio_authenticity("http://example.com/deepfake_voice.mp3")
        self.assertTrue(result['is_spoofed'])
        self.assertIn("synthesized digital vocoder pattern", result['reasons'][0])

if __name__ == '__main__':
    unittest.main()
