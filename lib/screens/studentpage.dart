import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Eklendi

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
  bool _isAlreadyLoggedIn = false; // Giriş yapılmış mı kontrolü
  String? _savedUserName; // Ekranda göstermek için isim

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // Sayfa açılınca kontrol et
    _setupConnectivityListener();
  }

  // --- 1. GİRİŞ DURUMU KONTROLÜ ---
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

  // --- SENKRONİZASYON (Aynı kalıyor) ---
  Future<void> _syncPendingData() async {
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

  // --- KAYIT VE GİRİŞ İŞLEMİ ---
  Future<void> _handleLogin() async {
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

      // --- KRİTİK NOKTA: Cihaza "Giriş Yapıldı" diye kaydediyoruz ---
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userName', plainName);

      // Ekranı güncelle
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

  // --- EKRAN TASARIMI ---
  @override
  Widget build(BuildContext context) {
    // Eğer giriş yapılmışsa direkt PECS/Uygulama ekranını göster
    if (_isAlreadyLoggedIn) {
      return _buildLoggedInView();
    }
    // Giriş yapılmamışsa Form ekranını göster
    else {
      return _buildLoginForm();
    }
  }

  // --- SENİN ANA UYGULAMA EKRANIN (PECS BURAYA GELECEK) ---
  Widget _buildLoggedInView() {
    return Scaffold(
      backgroundColor: const Color(0xFFD3EBF5),
      appBar: AppBar(
        title: Text("Merhaba, $_savedUserName 👋"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Çıkış yapma mantığı (Test için)
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
            const Icon(Icons.dashboard_customize, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text("PECS Kartları Ekranı", style: TextStyle(fontSize: 24)),
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

  // --- GİRİŞ FORMU TASARIMI (ESKİ KODUN AYNISI) ---
  Widget _buildLoginForm() {
    return Scaffold(
      backgroundColor: const Color(0xFFD3EBF5),
      appBar: AppBar(title: const Text("Öğrenci Girişi"), backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(Icons.school, size: 60, color: Color(0xFFFFB347)),
                  const SizedBox(height: 20),
                  const Text("İlk Defa Giriş", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("Bilgilerinizi sadece bir kere girmeniz yeterlidir.", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  _buildTextField(_nameController, "Adınız", Icons.person),
                  const SizedBox(height: 20),
                  _buildTextField(_surnameController, "Soyadınız", Icons.family_restroom),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _tcController,
                    keyboardType: TextInputType.number,
                    maxLength: 11,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputDecoration("TC Kimlik No", Icons.badge),
                    validator: (val) => (val == null || val.length != 11) ? "11 hane olmalı" : null,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB347)),
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Kaydet ve Başla", style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label, icon),
      validator: (value) => value!.isEmpty ? "$label boş bırakılamaz" : null,
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}