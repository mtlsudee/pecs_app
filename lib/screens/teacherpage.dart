import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/security_service.dart'; // Şifreleme servisimiz
import 'student_list_page.dart';
import 'parent_list_page.dart'; // <--- YENİ EKLENDİ

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key});

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  // --- KONTROLCÜLER VE DEĞİŞKENLER ---
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _tcController = TextEditingController();

  bool _isLoading = false;
  bool _isLoggedIn = false; // Öğretmen giriş yapmış mı?
  String? _teacherName;

  // Tasarım Renkleri (Öğretmen için mor tema)
  final Color _primaryColor = const Color(0xFF7C4DFF);
  final Color _backgroundColor = const Color(0xFFF3E5F5);

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // Sayfa açılınca kontrol et
  }

  // --- 1. GİRİŞ KONTROLÜ ---
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool loggedIn = prefs.getBool('isTeacherLoggedIn') ?? false;
    final String? name = prefs.getString('teacherName');

    if (loggedIn && name != null) {
      setState(() {
        _isLoggedIn = true;
        _teacherName = name;
      });
    }
  }

  // --- 2. KAYIT VE GİRİŞ İŞLEMİ ---
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Verileri Şifrele
      String plainName = _nameController.text;
      String encName = SecurityService.encryptData(plainName);
      String encSurname = SecurityService.encryptData(_surnameController.text);
      String encTC = SecurityService.encryptData(_tcController.text);

      // Firebase'e 'teachers' koleksiyonuna kaydet
      await FirebaseFirestore.instance.collection('teachers').add({
        'encryptedName': encName,
        'encryptedSurname': encSurname,
        'encryptedTC': encTC,
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'teacher'
      });

      // Telefona "Giriş Yapıldı" bilgisini kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isTeacherLoggedIn', true);
      await prefs.setString('teacherName', plainName);

      // Ekranı güncelle (Panele geçiş)
      setState(() {
        _isLoggedIn = true;
        _teacherName = plainName;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 3. ÇIKIŞ YAPMA ---
  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Tüm veriyi siler (Demo için)
    // Gerçekte sadece öğretmen verilerini silmek istersen: await prefs.remove('isTeacherLoggedIn');

    setState(() {
      _isLoggedIn = false;
      _nameController.clear();
      _surnameController.clear();
      _tcController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return _buildDashboard(); // Giriş yapılmışsa PANELİ göster
    } else {
      return _buildRegistrationForm(); // Giriş yapılmamışsa FORMU göster
    }
  }

  // --- A. ÖĞRETMEN PANELİ (BUTONLAR BURADA) ---
  Widget _buildDashboard() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Hoşgeldin, $_teacherName 👋", style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _handleLogout,
          )
        ],
      ),
      // --- DÜZELTME BURADA BAŞLIYOR ---
      body: Center(
        child: SingleChildScrollView( // <--- BU SATIR EKLENDİ (Kaydırma özelliği)
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Yönetim Paneli",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 40),

                // ÖĞRENCİ BUTONu
                _buildBigButton(
                  title: "Öğrenciler",
                  icon: Icons.face,
                  color: Colors.blueAccent,
                  onTap: () {
                    // --- BURAYI DEĞİŞTİRDİK: Listeye Git ---
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StudentListPage()),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // EBEVEYN BUTONU
                _buildBigButton(
                  title: "Ebeveynler",
                  icon: Icons.family_restroom,
                  color: Colors.orangeAccent,
                  onTap: () {
                    // --- BURAYI DEĞİŞTİRDİK: Listeye Git ---
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ParentListPage()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- B. KAYIT FORMU TASARIMI ---
  Widget _buildRegistrationForm() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Üst Başlık Alanı
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: _primaryColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Icon(Icons.person_pin_rounded, size: 80, color: _primaryColor),
                    const SizedBox(height: 10),
                    Text("Öğretmen Girişi", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryColor)),
                    const SizedBox(height: 5),
                    const Text("Lütfen bilgilerinizi kaydedin.", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

              // Form Alanı
              Padding(
                padding: const EdgeInsets.all(30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(_nameController, "Adınız", Icons.person_outline),
                      const SizedBox(height: 20),
                      _buildTextField(_surnameController, "Soyadınız", Icons.badge_outlined),
                      const SizedBox(height: 20),
                      _buildTextField(_tcController, "TC Kimlik No", Icons.pin_outlined, isNumber: true),
                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("KAYDET VE GİRİŞ YAP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Yardımcı: Büyük Seçim Butonları
  Widget _buildBigButton({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 35),
            ),
            const SizedBox(width: 20),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // Yardımcı: Text Field
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)] : [],
        validator: (val) => val!.isEmpty ? "$label gerekli" : null,
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon, color: _primaryColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}