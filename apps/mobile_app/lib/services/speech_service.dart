import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// SpeechService menghubungkan mikrofon perangkat ke stream string kata yang dikenali.
//
// Alasan Arsitektural (Why):
// Implementasi ini sengaja memisahkan logika Speech-to-Text ke service tersendiri
// agar SosBloc tetap murni sebagai state machine tanpa bergantung langsung ke
// permission mikrofon atau lifecycle speech engine. Pemisahan ini juga mempermudah
// mocking di unit test (cukup mock ApiService, bukan STT engine).
class SpeechService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  // Controller broadcast agar multiple listener (SosBloc) dapat subscribe secara independen.
  final StreamController<String> _phraseController =
      StreamController<String>.broadcast();

  bool _isListening = false;
  bool _isAvailable = false;

  Stream<String> get onPhrase => _phraseController.stream;
  bool get isListening => _isListening;

  // Inisialisasi permission mikrofon dan STT engine.
  // Mengembalikan true jika sistem berhasil diinisialisasi.
  Future<bool> initialize() async {
    _isAvailable = await _speechToText.initialize(
      onError: (error) {
        print('[SpeechService] STT error: ${error.errorMsg}');
      },
      onStatus: (status) {
        print('[SpeechService] STT status: $status');
        // Restart listening jika engine berhenti akibat timeout atau silence
        if (status == 'notListening' && _isListening) {
          _restartListening();
        }
      },
    );
    return _isAvailable;
  }

  // Memulai sesi listening latar belakang secara berkelanjutan.
  // Menggunakan localeId Bahasa Indonesia (id_ID) karena trigger phrase berbahasa Indonesia.
  void startListening() {
    if (!_isAvailable || _isListening) return;
    _isListening = true;
    _beginSession();
    print('[SpeechService] Background microphone listening started (id_ID).');
  }

  void _beginSession() {
    _speechToText.listen(
      onResult: (result) {
        if (result.recognizedWords.isNotEmpty) {
          print('[SpeechService] Phrase detected: "${result.recognizedWords}"');
          _phraseController.add(result.recognizedWords);
        }
      },
      localeId: 'id_ID',
      // listenMode continuous agar tidak otomatis berhenti setelah jeda singkat
      listenMode: stt.ListenMode.dictation,
      cancelOnError: false,
    );
  }

  void _restartListening() {
    if (!_isListening) return;
    // Delay singkat sebelum restart agar engine mendapatkan waktu idle
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isListening) {
        _beginSession();
        print('[SpeechService] STT session restarted after silence/timeout.');
      }
    });
  }

  // Menghentikan listening dan membersihkan resource.
  void stopListening() {
    _isListening = false;
    _speechToText.stop();
    print('[SpeechService] Background microphone listening stopped.');
  }

  void dispose() {
    stopListening();
    _phraseController.close();
  }
}
