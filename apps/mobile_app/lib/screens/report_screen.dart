import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  XFile? _selectedImage;
  bool _isLocating = false;
  bool _isUploading = false;
  bool _isAnalyzingAi = false;
  
  double? _latitude;
  double? _longitude;
  
  // AI analysis mock states
  String? _aiCaption;
  double? _aiAntiSpoofingScore;
  bool? _isSpoofed;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // Get GPS Location
  Future<void> _determinePosition() async {
    setState(() {
      _isLocating = true;
    });

    if (kIsWeb) {
      setState(() {
        _latitude = -6.8915;
        _longitude = 107.6161;
        _isLocating = false;
      });
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Default to Dago area Bandung if disabled
        _latitude = -6.8915;
        _longitude = 107.6161;
        setState(() => _isLocating = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _latitude = -6.8915;
          _longitude = 107.6161;
          setState(() => _isLocating = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _latitude = -6.8915;
        _longitude = 107.6161;
        setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );
      
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isLocating = false;
      });
    } catch (e) {
      // Fallback
      setState(() {
        _latitude = -6.8915;
        _longitude = 107.6161;
        _isLocating = false;
      });
    }
  }

  // Pick visual image
  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _aiCaption = null;
      _aiAntiSpoofingScore = null;
      _isSpoofed = null;
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
        
        // Trigger simulated AI Image Captioning & Anti-Spoofing
        _simulateAiAnalysis();
      } else {
        setState(() {});
      }
    } catch (e) {
      setState(() {});
    }
  }

  // Simulate AI model processing
  void _simulateAiAnalysis() {
    setState(() {
      _isAnalyzingAi = true;
    });

    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isAnalyzingAi = false;
          _aiCaption = "Terdeteksi pelaku kriminal begal membawa senjata tajam jenis cerurit berboncengan motor bebek tanpa pelat nomor.";
          _aiAntiSpoofingScore = 0.96; // 96% genuine
          _isSpoofed = false;
          // Set text controller to auto-generated description
          _descriptionController.text = _aiCaption!;
        });
        HapticFeedback.mediumImpact();
      }
    });
  }

  // Send visual report to API
  Future<void> _submitReport() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan lampirkan foto bukti kejadian terlebih dahulu.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
    });

    HapticFeedback.mediumImpact();

    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.createVisualReport(
        latitude: _latitude ?? -6.8915,
        longitude: _longitude ?? 107.6161,
        description: _descriptionController.text.trim(),
        imageUrl: 'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=400',
        antiSpoofingScore: _aiAntiSpoofingScore ?? 1.0,
        isSpoofed: _isSpoofed ?? false,
      );

      if (result['status'] == 'success') {
        HapticFeedback.lightImpact();
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E2638),
              title: const Text('Laporan Terkirim', style: TextStyle(color: Colors.white)),
              content: const Text(
                'Laporan visual Anda berhasil dikirim ke SIGAP Police Command Center dan disiarkan ke warga terdekat.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Back to Home
                  },
                  child: const Text('OK', style: TextStyle(color: Color(0xFFFF1744), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal mengirim laporan.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kesalahan jaringan. Gagal menghubungi server.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1219),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Laporan Visual Begal',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F1219),
              Color(0xFF161B26),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section: Upload Image Box
                  const Text(
                    'Foto Bukti Kejadian',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showImagePickerOptions();
                    },
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                      ),
                      child: _selectedImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_outlined, color: const Color(0xFFFF1744).withValues(alpha: 0.8), size: 40),
                                const SizedBox(height: 12),
                                const Text(
                                  'Ketuk untuk Ambil / Unggah Foto',
                                  style: TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Mendukung deteksi AI Anti-Spoofing',
                                  style: TextStyle(color: Colors.white24, fontSize: 10),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // In web context _selectedImage.path is a blob or base64
                                  _selectedImage!.path.startsWith('http') || _selectedImage!.path.startsWith('blob')
                                      ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                                      : Image.file(File(_selectedImage!.path), fit: BoxFit.cover, errorBuilder: (c, o, s) {
                                          return Image.network('https://images.unsplash.com/photo-1517649763962-0c623066013b?w=400', fit: BoxFit.cover);
                                        }),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                                          SizedBox(width: 4),
                                          Text('Ubah Foto', style: TextStyle(color: Colors.white, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section: AI Inference Results
                  if (_isAnalyzingAi)
                    GlassCard(
                      opacity: 0.04,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF1744)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AI Inference Server Sedang Menganalisis...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Mengidentifikasi pola foto & mendeteksi kecurangan (Anti-Spoofing)',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),

                  if (_aiCaption != null) ...[
                    GlassCard(
                      opacity: 0.04,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.psychology_rounded, color: Colors.tealAccent, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Hasil Analisis Copilot AI',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.tealAccent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'ANTI-SPOOF: OK',
                                  style: TextStyle(color: Colors.tealAccent, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Deskripsi Otomatis (Image Captioning):',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _aiCaption!,
                            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Skor Keaslian Kamera:',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                              ),
                              Text(
                                '${((_aiAntiSpoofingScore ?? 0.0) * 100).toStringAsFixed(0)}% Genuine Signature',
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Section: Geolocation Info Card
                  const Text(
                    'Lokasi Kejadian (GPS)',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  GlassCard(
                    opacity: 0.03,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Color(0xFFFF1744), size: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _isLocating
                                  ? const Text('Mencari sinyal satelit GPS...', style: TextStyle(color: Colors.white70, fontSize: 12))
                                  : Text(
                                      _latitude != null && _longitude != null
                                          ? 'Latitude: ${_latitude!.toStringAsFixed(6)}, Longitude: ${_longitude!.toStringAsFixed(6)}'
                                          : 'Koordinat belum ditentukan',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                              const SizedBox(height: 2),
                              Text(
                                _latitude != null && _longitude != null
                                    ? 'Lokasi berhasil terdeteksi otomatis'
                                    : 'Nyalakan GPS Anda untuk akurasi optimal',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.my_location_rounded, color: _isLocating ? Colors.white30 : Colors.tealAccent, size: 20),
                          onPressed: _isLocating ? null : _determinePosition,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Section: Manual Description Input
                  const Text(
                    'Detail Keterangan Tambahan',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Masukkan ciri-ciri pelaku, arah kabur, jenis motor, atau informasi pelengkap lainnya...',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.02),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFF1744), width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Keterangan wajib diisi untuk verifikasi manual';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Action: Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF1744),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                      shadowColor: const Color(0xFFFF1744).withValues(alpha: 0.4),
                    ),
                    onPressed: _isUploading ? null : _submitReport,
                    child: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'KIRIM LAPORAN VISUAL',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.0),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFFFF1744)),
              title: const Text('Ambil Foto Kamera', style: TextStyle(color: Colors.white, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFFF1744)),
              title: const Text('Pilih dari Galeri', style: TextStyle(color: Colors.white, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
