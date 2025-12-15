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
  // --- LOGIN & SİSTEM DEĞİŞKENLERİ ---
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _tcController = TextEditingController();

  bool _isLoading = false;
  bool _isAlreadyLoggedIn = false;
  String? _savedUserName;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  // Yeni Tasarım İçin Renk Paleti
  final Color _primaryColor = const Color(0xFF6C63FF);
  final Color _backgroundColor = const Color(0xFFF0F0F5);

  // --- PECS ARAYÜZ DEĞİŞKENLERİ ---
  String selectedCategory = "Hepsi";
  List<Map<String, dynamic>> sentenceStrip = []; // Üstteki cümle şeridi

  // KATEGORİ LİSTESİ
  final List<Map<String, dynamic>> categories = [
    {"id": "food", "label": "Yiyecek", "color": Colors.green, "icon": Icons.restaurant},
    {"id": "animals", "label": "Hayvanlar", "color": Colors.orange, "icon": Icons.pets},
    {"id": "feelings", "label": "Duygular", "color": Colors.amber, "icon": Icons.emoji_emotions},
    {"id": "places", "label": "Yerler", "color": Colors.purple, "icon": Icons.home},
    {"id": "transport", "label": "Araçlar", "color": Colors.blue, "icon": Icons.directions_car},
    {"id": "clothes", "label": "Kıyafet", "color": Colors.teal, "icon": Icons.checkroom},
  ];

  // KART LİSTESİ (Örnek Veriler)
  final List<Map<String, dynamic>> allCards = [
    {"id": "1", "text": "Elma", "emoji": "🍎", "category": "food"},
    {"id": "2", "text": "Muz", "emoji": "🍌", "category": "food"},
    {"id": "3", "text": "Kurabiye", "emoji": "🍪", "category": "food"},
    {"id": "4", "text": "Su", "emoji": "💧", "category": "food"},
    {"id": "5", "text": "Kedi", "emoji": "🐱", "category": "animals"},
    {"id": "6", "text": "Köpek", "emoji": "🐶", "category": "animals"},
    {"id": "7", "text": "Balık", "emoji": "🐟", "category": "animals"},
    {"id": "8", "text": "Kurbağa", "emoji": "🐸", "category": "animals"},
    {"id": "9", "text": "Mutlu", "emoji": "😊", "category": "feelings"},
    {"id": "10", "text": "Üzgün", "emoji": "😢", "category": "feelings"},
    {"id": "11", "text": "Kızgın", "emoji": "😠", "category": "feelings"},
    {"id": "12", "text": "Ev", "emoji": "🏠", "category": "places"},
    {"id": "13", "text": "Okul", "emoji": "🏫", "category": "places"},
    {"id": "14", "text": "Araba", "emoji": "🚗", "category": "transport"},
    {"id": "15", "text": "Otobüs", "emoji": "🚌", "category": "transport"},
    {"id": "16", "text": "Gömlek", "emoji": "👕", "category": "clothes"},
    {"id": "17", "text": "Ayakkabı", "emoji": "👟", "category": "clothes"},
  ];

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _setupConnectivityListener();
  }

  // --- SİSTEM FONKSİYONLARI ---
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
      return _buildPECSView();
    } else {
      return _buildLoginForm();
    }
  }

  // --- YENİ EKRAN: PECS ARAYÜZÜ ---
  Widget _buildPECSView() {
    final filteredCards = selectedCategory == "Hepsi"
        ? allCards
        : allCards.where((card) => card['category'] == selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: SafeArea(
        child: Column(
          children: [
            // ÜST BAR (Çıkış Butonu ve İsim)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Öğrenci: $_savedUserName", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      setState(() {
                        _isAlreadyLoggedIn = false;
                        sentenceStrip.clear();
                      });
                    },
                  )
                ],
              ),
            ),

            // CÜMLE ŞERİDİ (BEYAZ KUTU)
            Container(
              height: 100,
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue.shade100, width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                ],
              ),
              child: sentenceStrip.isEmpty
                  ? const Center(child: Text("Bir kart seçin...", style: TextStyle(color: Colors.grey, fontSize: 20)))
                  : ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(10),
                itemCount: sentenceStrip.length,
                itemBuilder: (context, index) {
                  final card = sentenceStrip[index];
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(card['emoji'], style: const TextStyle(fontSize: 32)),
                        Text(card['text'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 15),

            // KATEGORİ BUTONLARI
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCategoryButton("Hepsi", Colors.grey, Icons.apps, "Hepsi"),
                  ...categories.map((cat) => _buildCategoryButton(
                      cat['label'], cat['color'], cat['icon'], cat['id']
                  )).toList(),
                  const SizedBox(width: 10),
                  _buildActionButton(Icons.volume_up, Colors.black87, () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Seslendiriliyor... 🔊")));
                  }),
                  const SizedBox(width: 10),
                  _buildActionButton(Icons.refresh, Colors.redAccent, () {
                    setState(() { sentenceStrip.clear(); });
                  }),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // KART IZGARASI
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                ),
                itemCount: filteredCards.length,
                itemBuilder: (context, index) {
                  final card = filteredCards[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() { sentenceStrip.add(card); });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(card['emoji'], style: const TextStyle(fontSize: 40)),
                          const SizedBox(height: 10),
                          Text(
                            card['text'],
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODERN GİRİŞ FORMU ---
  Widget _buildLoginForm() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Üst Kısım
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: _primaryColor),
                        onPressed: () {
                          Navigator.pop(context); // Geri Dön
                        },
                      ),
                    ),
                    Icon(Icons.school_rounded, size: 100, color: _primaryColor),
                    const SizedBox(height: 20),
                    Text(
                      "Giriş Yap",
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _primaryColor),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Lütfen bilgilerinizi girerek devam edin.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // Form
              Padding(
                padding: const EdgeInsets.all(30.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildModernTextField(controller: _nameController, hintText: "Adınız", icon: Icons.person_outline_rounded),
                      const SizedBox(height: 20),
                      _buildModernTextField(controller: _surnameController, hintText: "Soyadınız", icon: Icons.badge_outlined),
                      const SizedBox(height: 20),
                      _buildModernTextField(controller: _tcController, hintText: "TC Kimlik No", icon: Icons.pin_outlined, isNumber: true,
                        validator: (val) => (val == null || val.length != 11) ? "11 haneli olmalıdır" : null,
                      ),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 5,
                            shadowColor: _primaryColor.withOpacity(0.4),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("GİRİŞ YAP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Yardımcı Widget'lar
  Widget _buildCategoryButton(String label, Color color, IconData icon, String id) {
    bool isSelected = selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ElevatedButton.icon(
        onPressed: () { setState(() { selectedCategory = id; }); },
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: isSelected ? 8 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isSelected ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 50,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
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
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        ),
      ),
    );
  }
}