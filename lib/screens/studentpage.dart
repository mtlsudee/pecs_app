import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../services/database_helper.dart';
import '../services/security_service.dart';

class StudentPage extends StatefulWidget {
  const StudentPage({super.key});

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  final FlutterTts flutterTts = FlutterTts();

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
  List<Map<String, dynamic>> allCards = [];

  // 1. ANA KATEGORİLER
  final List<Map<String, dynamic>> mainCategories = [
    {"id": "beslenme", "label": "Beslenme", "color": const Color(0xFFFFB74D), "icon": Icons.restaurant, "hasSub": true},
    {"id": "canlilar", "label": "Canlılar", "color": const Color(0xFF8BC34A), "icon": Icons.pets, "hasSub": true},
    {"id": "eylemler", "label": "Eylemler", "color": const Color(0xFFE86868), "icon": Icons.directions_run, "hasSub": true},
    {"id": "nesneler", "label": "Nesneler", "color": const Color(0xFF2196F3), "icon": Icons.chair, "hasSub": true},
    {"id": "ozellikler", "label": "Özellikler", "color": const Color(0xFFA93DAC), "icon": Icons.palette, "hasSub": true},
    {"id": "vucut", "label": "Vücut", "color": const Color(0xFFEA8DEC), "icon": Icons.accessibility_new, "hasSub": false},
    {"id": "yerler", "label": "Yerler", "color": const Color(0xFFFFF176), "icon": Icons.location_on, "hasSub": false},
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

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _setupConnectivityListener();
    _loadCardsFromAssets();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("tr-TR");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setPitch(1.0);
  }

  Future<void> _speakSentence() async {
    if (sentenceStrip.isEmpty) return;
    String sentence = sentenceStrip.map((card) => card['text']).join(" ");
    await flutterTts.speak(sentence);
  }

  Future<void> _loadCardsFromAssets() async {
    try {
      final manifestContent = await DefaultAssetBundle.of(context).loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      final imagePaths = manifestMap.keys
          .where((String key) => key.contains('assets/'))
          .where((String key) => key.endsWith('.png') || key.endsWith('.jpg'))
          .toList();

      List<Map<String, dynamic>> detectedCards = [];

      for (String path in imagePaths) {
        String categoryId = "";
        if (path.contains("atistirmalik")) categoryId = "atistirmalik";
        else if (path.contains("icecek")) categoryId = "icecek";
        else if (path.contains("meyve")) categoryId = "meyve";
        else if (path.contains("ogun_yemekler")) categoryId = "ogun";
        else if (path.contains("sebze")) categoryId = "sebze";
        else if (path.contains("Bitki")) categoryId = "bitki";
        else if (path.contains("Hayvanlar")) categoryId = "hayvanlar";
        else if (path.contains("Insan_rolleri")) categoryId = "insan_rolleri";
        else if (path.contains("Meslekler")) categoryId = "meslekler";
        else if (path.contains("Gunluk_eylemler")) categoryId = "gunluk";
        else if (path.contains("Oz_Bakim")) categoryId = "ozbakim";
        else if (path.contains("Aksesuarlar")) categoryId = "aksesuar";
        else if (path.contains("Arac_gerecler")) categoryId = "arac_gerec";
        else if (path.contains("Ev_esyalari")) categoryId = "ev_esyasi";
        else if (path.contains("Oyuncaklar")) categoryId = "oyuncak";
        else if (path.contains("Duygular")) categoryId = "duygular";
        else if (path.contains("Renkler")) categoryId = "renkler";
        else if (path.contains("Sayilar")) categoryId = "sayilar";
        else if (path.contains("Vucut_Bolumleri")) categoryId = "vucut";
        else if (path.contains("Yerler")) categoryId = "yerler";

        if (categoryId.isNotEmpty) {
          String filename = path.split('/').last.split('.').first;
          String cleanName = filename.replaceAll('_', ' ');
          String displayName = cleanName.isEmpty ? "" : cleanName[0].toUpperCase() + cleanName.substring(1);

          detectedCards.add({
            "text": displayName,
            "image": path,
            "category": categoryId,
          });
        }
      }

      if (mounted) {
        setState(() {
          allCards = detectedCards;
        });
      }
    } catch (e) {
      print("Kart yükleme hatası: $e");
    }
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
    flutterTts.stop();
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

  // --- ANA EKRAN YAPISI (TAM SAYFA KAYDIRMALI) ---
  Widget _buildPECSView() {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: SafeArea(
        // SingleChildScrollView TÜM SAYFAYI KAPLIYOR
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(), // Yaylanarak kaydırma
          child: Column(
            children: [
              // 1. HEADER
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
              _buildVelcroSentenceStrip(),

              // 3. ANA KATEGORİ MENÜSÜ (BÜYÜK BOYUT)
              SizedBox(
                height: 90,
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                                color: cat['color'],
                                borderRadius: BorderRadius.circular(15),
                                border: isSelected ? Border.all(color: Colors.black54, width: 3) : null,
                                boxShadow: [BoxShadow(color: cat['color'].withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))]
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(cat['icon'], color: Colors.white, size: 30),
                                const SizedBox(height: 5),
                                Text(
                                  cat['label'],
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    Row(
                      children: [
                        _buildActionBtn(Icons.volume_up_rounded, Colors.green, _speakSentence, label: "Oku"),
                        const SizedBox(width: 5),
                        _buildActionBtn(Icons.refresh_rounded, Colors.red, () {
                          setState(() { sentenceStrip.clear(); });
                        }, label: "Sil"),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 4. İÇERİK ALANI
              // Sabit yükseklik ve Expanded YOK. İçerik kadar uzayacak.
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: _buildDynamicContent(),
              ),

              const SizedBox(height: 40), // Alt boşluk
            ],
          ),
        ),
      ),
    );
  }

  // --- İÇERİK GÖSTERİMİ (DİKEY ve KAYDIRILAMAZ) ---
  // Çünkü ana sayfa zaten kaydırılıyor (SingleChildScrollView)
  Widget _buildDynamicContent() {
    if (currentMainCategory == null) {
      return const SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app, size: 80, color: Colors.grey),
              SizedBox(height: 20),
              Text("Lütfen yukarıdan bir kategori seçin.", style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    final selectedMain = mainCategories.firstWhere((c) => c['id'] == currentMainCategory);

    // A) ALT KATEGORİ SEÇİMİ
    if (selectedMain['hasSub'] == true && currentSubCategory == null) {
      final subs = subCategories[currentMainCategory] ?? [];
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("${selectedMain['label']} > Alt Kategori Seçin", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          GridView.builder(
            shrinkWrap: true, // ÖNEMLİ: Kendi scroll'unu kapat
            physics: const NeverScrollableScrollPhysics(), // ÖNEMLİ: Sayfa scroll'una uy
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

    // B) KART LİSTELEME
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
            ? const SizedBox(height: 200, child: Center(child: Text("Bu kategoride kart bulunamadı.", style: TextStyle(color: Colors.grey))))
            : GridView.builder(
          shrinkWrap: true, // ÖNEMLİ
          physics: const NeverScrollableScrollPhysics(), // ÖNEMLİ
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
                setState(() {
                  Map<String, dynamic> newCard = Map.from(card);
                  newCard['uniqueId'] = DateTime.now().millisecondsSinceEpoch.toString();
                  sentenceStrip.add(newCard);
                });
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
                  children: [
                    if(card['image'] != null)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: Image.asset(card['image'], fit: BoxFit.contain),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        card['text'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
    final main = mainCategories.firstWhere((c) => c['id'] == currentMainCategory, orElse: () => {'label': ''});
    if (currentSubCategory == null) return main['label'];
    final subs = subCategories[currentMainCategory] ?? [];
    final sub = subs.firstWhere((s) => s['id'] == currentSubCategory, orElse: () => {'label': ''});
    return sub['label'];
  }

  Widget _buildVelcroSentenceStrip() {
    return Container(
      height: 110,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.shade100, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 25,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
            ),
          ),
          sentenceStrip.isEmpty
              ? const Center(child: Text("Bir kart seçin...", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))
              : ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            buildDefaultDragHandles: true,
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                elevation: 10,
                child: child,
              );
            },
            onReorder: (int oldIndex, int newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = sentenceStrip.removeAt(oldIndex);
                sentenceStrip.insert(newIndex, item);
              });
            },
            itemCount: sentenceStrip.length,
            itemBuilder: (context, index) {
              final card = sentenceStrip[index];
              return GestureDetector(
                key: ValueKey(card['uniqueId']),
                onTap: () {
                  setState(() {
                    sentenceStrip.removeAt(index);
                  });
                },
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade400),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if(card['image'] != null) Image.asset(card['image'], width: 45, height: 45, errorBuilder: (c,o,s) => const Icon(Icons.image)),
                      Text(card['text'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, Color color, VoidCallback onTap, {String label = ""}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              if(label.isNotEmpty)
                Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
}