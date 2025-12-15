import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/database_helper.dart';
import '../services/security_service.dart';

class StudentPage extends StatefulWidget {
  const StudentPage({super.key});

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  // Form Kontrolcüleri
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _tcController = TextEditingController();

  bool _isLoading = false;
  bool _isAlreadyLoggedIn = false;
  String? _savedUserName;

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  // Yeni Tasarım İçin Renk Paleti (Referans görsele uygun mor tonları)
  final Color _primaryColor = const Color(0xFF6C63FF); // Ana mor renk
  final Color _backgroundColor = const Color(0xFFF0F0F5); // Açık gri arka plan
  final Color _inputFillColor = Colors.white; // Input içi beyaz

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _setupConnectivityListener();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? name = prefs.getString('userName');

    if (isLoggedIn && name != null) {
      setState(() {
        _isAlreadyLoggedIn = true;
        _savedUserName = name;
      });
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi)) {
        _syncPendingData();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _nameController.dispose();
    _surnameController.dispose();
    _tcController.dispose();
    super.dispose();
  }

  Future<void> _syncPendingData() async {
    // Senkronizasyon mantığı aynen kalıyor
    final unsyncedRecords = await DatabaseHelper.instance.getUnsyncedStudents();
    if (unsyncedRecords.isEmpty) return;

    for (var record in unsyncedRecords) {
      try {
        await FirebaseFirestore.instance.collection('students').add({
          'encryptedName': record['encryptedName'],
          'encryptedSurname': record['encryptedSurname'],
          'encryptedTC': record['encryptedTC'],
          'createdAt': FieldValue.serverTimestamp(),
          'deviceSource': 'android_offline_sync'
        });
        await DatabaseHelper.instance.updateStudentSyncStatus(record['id'], 1);
      } catch (e) {
        print("Senkronizasyon hatası: $e");
      }
    }
  }

  Future<void> _handleLogin() async {
    // Kayıt mantığı aynen kalıyor
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      String plainName = _nameController.text;
      String encName = SecurityService.encryptData(plainName);
      String encSurname = SecurityService.encryptData(_surnameController.text);
      String encTC = SecurityService.encryptData(_tcController.text);

      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOnline = connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.wifi);

      if (isOnline) {
        await FirebaseFirestore.instance.collection('students').add({
          'encryptedName': encName,
          'encryptedSurname': encSurname,
          'encryptedTC': encTC,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await DatabaseHelper.instance.createStudent({
          'encryptedName': encName,
          'encryptedSurname': encSurname,
          'encryptedTC': encTC,
          'isSynced': 1
        });
      } else {
        await DatabaseHelper.instance.createStudent({
          'encryptedName': encName,
          'encryptedSurname': encSurname,
          'encryptedTC': encTC,
          'isSynced': 0
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userName', plainName);

      setState(() {
        _isAlreadyLoggedIn = true;
        _savedUserName = plainName;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAlreadyLoggedIn) {
      return _buildLoggedInView();
    } else {
      return _buildLoginForm();
    }
  }

  Widget _buildLoggedInView() {
    // Giriş yapıldıktan sonraki ekran (Aynı kalıyor, sadece renkler güncellendi)
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text("Merhaba, $_savedUserName 👋", style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              setState(() {
                _isAlreadyLoggedIn = false;
              });
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_customize, size: 80, color: _primaryColor),
            const SizedBox(height: 20),
            const Text("PECS Kartları Ekranı", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                "Burası öğrencinin sürekli göreceği ekran. Bir kere giriş yaptıktan sonra hep burası açılacak.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- YENİ TASARIMLI GİRİŞ FORMU ---
  Widget _buildLoginForm() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Üst Kısım (Başlık ve İllüstrasyon Alanı)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(30, 80, 30, 40),
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  // İllüstrasyon yerine şık bir ikon kullanıyoruz
                  Icon(Icons.school_rounded, size: 100, color: _primaryColor),
                  const SizedBox(height: 20),
                  Text(
                    "Hoş Geldiniz",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Lütfen bilgilerinizi girerek devam edin.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Form Alanı
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // İsim Alanı
                    _buildModernTextField(
                      controller: _nameController,
                      hintText: "Adınız",
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 20),

                    // Soyisim Alanı
                    _buildModernTextField(
                      controller: _surnameController,
                      hintText: "Soyadınız",
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 20),

                    // TC Kimlik Alanı
                    _buildModernTextField(
                      controller: _tcController,
                      hintText: "TC Kimlik No",
                      icon: Icons.pin_outlined,
                      isNumber: true,
                      validator: (val) => (val == null || val.length != 11) ? "11 haneli olmalıdır" : null,
                    ),
                    const SizedBox(height: 40),

                    // Giriş Butonu
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 5,
                          shadowColor: _primaryColor.withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          "GİRİŞ YAP",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Modern TextField Tasarımı
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _inputFillColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)] : [],
        validator: validator ?? (value) => value!.isEmpty ? "$hintText boş bırakılamaz" : null,
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Icon(icon, color: _primaryColor),
          ),
          border: InputBorder.none, // Varsayılan alt çizgiyi kaldır
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        ),
      ),
    );
  }
}