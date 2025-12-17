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
  // --- RENK TANIMLARI ---
  final Color _primaryColor = const Color(0xFF6C63FF);
  final Color _backgroundColor = const Color(0xFFF0F0F5);

  // --- SİSTEM DEĞİŞKENLERİ ---
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _tcController = TextEditingController();

  bool _isLoading = false;
  bool _isAlreadyLoggedIn = false;
  String? _savedUserName;
  String? _currentEncryptedTC;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  // --- NAVİGASYON DEĞİŞKENLERİ ---
  String? currentMainCategory;
  String? currentSubCategory;

  List<Map<String, dynamic>> sentenceStrip = [];

  // 1. ANA KATEGORİLER
  final List<Map<String, dynamic>> mainCategories = [
    {"id": "beslenme", "label": "Beslenme", "color": Colors.green, "icon": Icons.restaurant, "hasSub": true},
    {"id": "canlilar", "label": "Canlılar", "color": Colors.orange, "icon": Icons.pets, "hasSub": true},
    {"id": "eylemler", "label": "Eylemler", "color": Colors.blue, "icon": Icons.directions_run, "hasSub": true},
    {"id": "nesneler", "label": "Nesneler", "color": Colors.purple, "icon": Icons.chair, "hasSub": true},
    {"id": "ozellikler", "label": "Özellikler", "color": Colors.teal, "icon": Icons.palette, "hasSub": true},
    {"id": "vucut", "label": "Vücut", "color": Colors.redAccent, "icon": Icons.accessibility_new, "hasSub": false},
    {"id": "yerler", "label": "Yerler", "color": Colors.brown, "icon": Icons.location_on, "hasSub": false},
  ];

  // 2. ALT KATEGORİLER
  final Map<String, List<Map<String, dynamic>>> subCategories = {
    "beslenme": [
      {"id": "atistirmalik", "label": "Atıştırmalık", "icon": Icons.cookie},
      {"id": "icecek", "label": "İçecek", "icon": Icons.local_drink},
      {"id": "meyve", "label": "Meyve", "icon": Icons.eco},
      {"id": "ogun", "label": "Öğün", "icon": Icons.soup_kitchen},
      {"id": "sebze", "label": "Sebze", "icon": Icons.grass},
    ],
    "canlilar": [
      {"id": "bitki", "label": "Bitki", "icon": Icons.local_florist},
      {"id": "hayvanlar", "label": "Hayvanlar", "icon": Icons.pets},
      {"id": "insan_rolleri", "label": "İnsanlar", "icon": Icons.people},
      {"id": "meslekler", "label": "Meslekler", "icon": Icons.work},
    ],
    "eylemler": [
      {"id": "gunluk", "label": "Günlük", "icon": Icons.wb_sunny},
      {"id": "ozbakim", "label": "Öz Bakım", "icon": Icons.wash},
    ],
    "nesneler": [
      {"id": "aksesuar", "label": "Aksesuarlar", "icon": Icons.watch},
      {"id": "arac_gerec", "label": "Araçlar", "icon": Icons.build},
      {"id": "ev_esyasi", "label": "Ev Eşyası", "icon": Icons.tv},
      {"id": "oyuncak", "label": "Oyuncak", "icon": Icons.toys},
    ],
    "ozellikler": [
      {"id": "duygular", "label": "Duygular", "icon": Icons.emoji_emotions},
      {"id": "renkler", "label": "Renkler", "icon": Icons.color_lens},
      {"id": "sayilar", "label": "Sayılar", "icon": Icons.format_list_numbered},
    ],
  };

  // 3. KARTLAR
  final List<Map<String, dynamic>> allCards = [
    // BESLENME -> MEYVE
    {"text": "Elma", "image": "assets/cards/Kartlar/Beslenme/Meyve/elma.png", "category": "meyve"},
    {"text": "Armut", "image": "assets/cards/Kartlar/Beslenme/Meyve/armut.png", "category": "meyve"},
    {"text": "Muz", "image": "assets/cards/Kartlar/Beslenme/Meyve/muz.png", "category": "meyve"},

    // --- CANLILAR > BİTKİ GRUBU ---
   /* {"text": "Ayçiçeği", "image": "assets/Canlilar/Bitki/aycicegi.png", "category": "bitki"},
    {"text": "Bitki", "image": "assets/Canlilar/Bitki/bitki.png", "category": "bitki"},
    {"text": "Çiçek", "image": "assets/Canlilar/Bitki/cicek.png", "category": "bitki"},
    {"text": "Gül", "image": "assets/Canlilar/Bitki/gul.png", "category": "bitki"},
    {"text": "Kaktüs", "image": "assets/Canlilar/Bitki/kaktus.png", "category": "bitki"},
    {"text": "Karanfil", "image": "assets/Canlilar/Bitki/karanfil_cicegi.png", "category": "bitki"},
    {"text": "Kök", "image": "assets/Canlilar/Bitki/kok.png", "category": "bitki"},
    {"text": "Lale", "image": "assets/Canlilar/Bitki/lale.png", "category": "bitki"},
    {"text": "Lavanta", "image": "assets/Canlilar/Bitki/lavanta.png", "category": "bitki"},
    {"text": "Palmiye", "image": "assets/Canlilar/Bitki/palmiye.png", "category": "bitki"},
    {"text": "Papatya", "image": "assets/Canlilar/Bitki/papatya.png", "category": "bitki"},
    {"text": "Yaprak", "image": "assets/Canlilar/Bitki/yaprak.png", "category": "bitki"}, // İsmini düzelttin varsayıyorum
    {"text": "Yonca", "image": "assets/Canlilar/Bitki/yonca.png", "category": "bitki"},*/

    // BESLENME -> İÇECEK
    {"text": "Su", "emoji": "💧", "category": "icecek"},
    {"text": "Süt", "emoji": "🥛", "category": "icecek"},

    // CANLILAR -> HAYVANLAR
    {"text": "Kedi", "emoji": "🐱", "category": "hayvanlar"},
    {"text": "Köpek", "emoji": "🐶", "category": "hayvanlar"},

    // ÖZELLİKLER -> DUYGULAR
    {"text": "Mutlu", "emoji": "😊", "category": "duygular"},
    {"text": "Üzgün", "emoji": "😢", "category": "duygular"},

    // YERLER
    {"text": "Ev", "emoji": "🏠", "category": "yerler"},
    {"text": "Okul", "emoji": "🏫", "category": "yerler"},

    // VÜCUT
    {"text": "Baş", "emoji": "🙆", "category": "vucut"},
    {"text": "Kol", "emoji": "💪", "category": "vucut"},
  ];

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
    final String? savedTC = prefs.getString('studentEncryptedTC');
    if (isLoggedIn && name != null) {
      setState(() {
        _isAlreadyLoggedIn = true;
        _savedUserName = name;
        if(savedTC != null) _currentEncryptedTC = savedTC;
      });
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.mobile) || results.contains(ConnectivityResult.wifi)) {
        _syncPendingData();
      }
    });
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

  Future<void> kartSeciminiKaydet(String kartIsmi, String kategori) async {
    String gonderilecekTC = _currentEncryptedTC ?? "MISAFIR_OGRENCI";
    try {
      await FirebaseFirestore.instance.collection('card_logs').add({
        'studentTC': gonderilecekTC,
        'cardText': kartIsmi,
        'category': kategori,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().split('T')[0],
      });
    } catch (e) {
      print("Hata: $e");
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
      _currentEncryptedTC = encTC;

      final connectivityResult = await Connectivity().checkConnectivity();
      bool isOnline = connectivityResult.contains(ConnectivityResult.mobile) || connectivityResult.contains(ConnectivityResult.wifi);

      if (isOnline) {
        await FirebaseFirestore.instance.collection('students').add({
          'encryptedName': encName, 'encryptedSurname': encSurname, 'encryptedTC': encTC, 'createdAt': FieldValue.serverTimestamp(),
        });
        await DatabaseHelper.instance.createStudent({'encryptedName': encName, 'encryptedSurname': encSurname, 'encryptedTC': encTC, 'isSynced': 1});
      } else {
        await DatabaseHelper.instance.createStudent({'encryptedName': encName, 'encryptedSurname': encSurname, 'encryptedTC': encTC, 'isSynced': 0});
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userName', plainName);
      await prefs.setString('studentEncryptedTC', encTC);

      setState(() { _isAlreadyLoggedIn = true; _savedUserName = plainName; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _nameController.dispose();
    _surnameController.dispose();
    _tcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAlreadyLoggedIn) {
      return _buildPECSView();
    } else {
      return _buildLoginForm();
    }
  }

  // --- DÜZELTİLMİŞ TASARIM (TÜM SAYFA KAYIYOR) ---
  Widget _buildPECSView() {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: SafeArea(
        // SingleChildScrollView: Sayfanın tamamının tek bir parça gibi kaymasını sağlar.
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(), // Yaylanma efekti (iOS tarzı)
          child: Column(
            children: [
              // 1. HEADER (Geri Dön / İsim / Çıkış)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 18,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.arrow_back, color: Colors.blue, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text("Merhaba, $_savedUserName 👋", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const Spacer(),
                    CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      radius: 18,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.logout, color: Colors.red, size: 20),
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          setState(() { _isAlreadyLoggedIn = false; _currentEncryptedTC = null; sentenceStrip.clear(); currentMainCategory = null; currentSubCategory = null; });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 2. CÜMLE ŞERİDİ
              Container(
                height: 110,
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                    boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))]
                ),
                child: sentenceStrip.isEmpty
                    ? const Center(child: Text("Bir kart seçin...", style: TextStyle(color: Colors.grey, fontSize: 18)))
                    : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(10),
                  itemCount: sentenceStrip.length,
                  itemBuilder: (context, index) {
                    final card = sentenceStrip[index];
                    return Container(
                      width: 85,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if(card['image'] != null) Image.asset(card['image'], width: 45, height: 45, errorBuilder: (c,o,s) => const Icon(Icons.image)),
                          if(card['emoji'] != null) Text(card['emoji'], style: const TextStyle(fontSize: 35)),
                          Text(card['text'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // 3. YATAY KATEGORİ MENÜSÜ
              SizedBox(
                height: 65,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    ...mainCategories.map((cat) {
                      bool isSelected = currentMainCategory == cat['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              currentMainCategory = cat['id'];
                              currentSubCategory = null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                                color: cat['color'],
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected ? Border.all(color: Colors.black54, width: 3) : null,
                                boxShadow: [BoxShadow(color: cat['color'].withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))]
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(cat['icon'], color: Colors.white, size: 20),
                                const SizedBox(height: 2),
                                Text(
                                  cat['label'],
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    _buildActionBtn(Icons.volume_up, Colors.grey.shade800, () {}),
                    _buildActionBtn(Icons.refresh, Colors.red, () {
                      setState(() { sentenceStrip.clear(); });
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 4. İÇERİK ALANI
              // Burası artık Expanded değil, sayfanın akışına göre uzayan bir alan.
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: _buildDynamicContent(),
              ),

              const SizedBox(height: 20), // Sayfa altı boşluğu
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildDynamicContent() {
    if (currentMainCategory == null) {
      // İçerik az olduğu için yükseklik veriyoruz ki sayfa boş kalmasın
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app, size: 80, color: Colors.blue.shade100),
              const SizedBox(height: 20),
              const Text(
                "Lütfen yukarıdan bir kategori seçin.",
                style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    final selectedMain = mainCategories.firstWhere((c) => c['id'] == currentMainCategory);

    // ALT KATEGORİ SEÇİMİ
    if (selectedMain['hasSub'] == true && currentSubCategory == null) {
      final subs = subCategories[currentMainCategory] ?? [];

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("${selectedMain['label']} > Alt Kategori Seçin", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          // GridView.builder'ı shrinkWrap: true ve physics: NeverScrollableScrollPhysics
          // ile sarmalıyoruz ki ana sayfanın kaymasını bozmasın.
          GridView.builder(
            shrinkWrap: true, // İÇERİK KADAR YER KAPLA
            physics: const NeverScrollableScrollPhysics(), // KENDİ İÇİNDE KAYDIRMA, SAYFAYLA BERABER KAY
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 2.5,
            ),
            itemCount: subs.length,
            itemBuilder: (context, index) {
              final sub = subs[index];
              return InkWell(
                onTap: () {
                  setState(() {
                    currentSubCategory = sub['id'];
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: selectedMain['color'], width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(sub['icon'], color: selectedMain['color'], size: 30),
                      const SizedBox(width: 10),
                      Text(sub['label'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    // KART LİSTELEME
    String filterId = currentSubCategory ?? currentMainCategory!;
    final filteredCards = allCards.where((card) => card['category'] == filterId).toList();

    return Column(
      children: [
        if (currentSubCategory != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => currentSubCategory = null),
                  child: Row(
                    children: const [
                      Icon(Icons.arrow_back_ios, size: 16, color: Colors.blue),
                      Text("Geri Dön", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                Text(_getCurrentTitle(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
              ],
            ),
          ),

        filteredCards.isEmpty
            ? const SizedBox(height: 200, child: Center(child: Text("Bu kategoride kart yok.", style: TextStyle(color: Colors.grey))))
            : GridView.builder(
          shrinkWrap: true, // İÇERİK KADAR YER KAPLA
          physics: const NeverScrollableScrollPhysics(), // SAYFAYLA BERABER KAY
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: filteredCards.length,
          itemBuilder: (context, index) {
            final card = filteredCards[index];
            return GestureDetector(
              onTap: () {
                setState(() { sentenceStrip.add(card); });
                kartSeciminiKaydet(card['text'], _getCurrentTitle());
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if(card['image'] != null)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Image.asset(card['image'], fit: BoxFit.contain, errorBuilder: (c,o,s) => const Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                      ),
                    if(card['emoji'] != null)
                      Text(card['emoji'], style: const TextStyle(fontSize: 40)),

                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        card['text'],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _getCurrentTitle() {
    if (currentMainCategory == null) return "";
    final main = mainCategories.firstWhere((c) => c['id'] == currentMainCategory);
    if (currentSubCategory == null) return main['label'];
    final subs = subCategories[currentMainCategory] ?? [];
    final sub = subs.firstWhere((s) => s['id'] == currentSubCategory, orElse: () => {'label': ''});
    return sub['label'];
  }

  // --- LOGIN FORMU ---
  Widget _buildLoginForm() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                decoration: BoxDecoration(color: _backgroundColor, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40))),
                child: Column(
                  children: [
                    Align(alignment: Alignment.topLeft, child: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: _primaryColor), onPressed: () => Navigator.pop(context))),
                    Icon(Icons.school_rounded, size: 100, color: _primaryColor),
                    const SizedBox(height: 20),
                    Text("Giriş Yap", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _primaryColor)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(30.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildModernTextField(controller: _nameController, hintText: "Adınız", icon: Icons.person_outline_rounded),
                      const SizedBox(height: 10),
                      _buildModernTextField(controller: _surnameController, hintText: "Soyadınız", icon: Icons.badge_outlined),
                      const SizedBox(height: 10),
                      _buildModernTextField(controller: _tcController, hintText: "TC Kimlik No", icon: Icons.pin_outlined, isNumber: true, validator: (val) => (val == null || val.length != 11) ? "11 haneli olmalıdır" : null),
                      const SizedBox(height: 20),
                      SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: _isLoading ? null : _handleLogin, style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("GİRİŞ YAP VE KAYDET", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
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

  Widget _buildModernTextField({required TextEditingController controller, required String hintText, required IconData icon, bool isNumber = false, String? Function(String?)? validator}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
      child: TextFormField(controller: controller, keyboardType: isNumber ? TextInputType.number : TextInputType.text, inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)] : [], validator: validator ?? (value) => value!.isEmpty ? "$hintText boş bırakılamaz" : null, decoration: InputDecoration(hintText: hintText, hintStyle: TextStyle(color: Colors.grey.shade400), prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Icon(icon, color: _primaryColor)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20))),
    );
  }
}