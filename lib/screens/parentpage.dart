import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/security_service.dart'; // Şifreleme servisi

class ParentPage extends StatefulWidget {
  const ParentPage({super.key});

  @override
  State<ParentPage> createState() => _ParentPageState();
}

class _ParentPageState extends State<ParentPage> {
  // --- DEĞİŞKENLER ---
  final _formKey = GlobalKey<FormState>();

  // Veli Bilgileri
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _surnameController = TextEditingController();
  final TextEditingController _tcController = TextEditingController();

  // Öğrenci Bilgileri (Doğrulama için)
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _studentTcController = TextEditingController();

  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _parentName;

  // Tasarım Renkleri
  final Color _primaryColor = Colors.orangeAccent.shade700;
  final Color _backgroundColor = const Color(0xFFFFF3E0);

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // --- 1. OTURUM KONTROLÜ ---
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool loggedIn = prefs.getBool('isParentLoggedIn') ?? false;
    final String? name = prefs.getString('parentName');

    if (loggedIn && name != null) {
      setState(() {
        _isLoggedIn = true;
        _parentName = name;
      });
    }
  }

  // --- 2. KAYIT VE DOĞRULAMA İŞLEMİ (GÜNCELLENDİ) ---
  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Önce girilen Öğrenci TC'sini şifrele (Çünkü veritabanında şifreli duruyor)
      String encStudentTC = SecurityService.encryptData(_studentTcController.text);

      // 2. Firebase'e sor: "students" tablosunda bu şifreli TC var mı?
      // NOT: Bu sorgunun çalışması için şifreleme yönteminin her seferinde aynı çıktıyı vermesi gerekir.
      // Eğer veritabanında kayıtlı TC ile buradaki şifreli hal eşleşmezse öğrenci bulunamaz.
      final studentQuery = await FirebaseFirestore.instance
          .collection('students')
          .where('encryptedTC', isEqualTo: encStudentTC)
          .get();

      // 3. Sonucu Kontrol Et
      if (studentQuery.docs.isEmpty) {
        // HATA: Öğrenci bulunamadı!
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("HATA: Bu TC Kimlik numarasına sahip bir öğrenci bulunamadı! Lütfen öğrenci kaydının yapıldığından emin olun."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        setState(() => _isLoading = false);
        return; // İşlemi burada durdur, kaydetme!
      }

      // --- EĞER BURAYA GELDİYSE ÖĞRENCİ VAR DEMEKTİR ---

      // Veli verilerini şifrele
      String encName = SecurityService.encryptData(_nameController.text);
      String encSurname = SecurityService.encryptData(_surnameController.text);
      String encTC = SecurityService.encryptData(_tcController.text);
      String encStudentName = SecurityService.encryptData(_studentNameController.text);

      // Kaydı Yap
      await FirebaseFirestore.instance.collection('parents').add({
        'encryptedName': encName,
        'encryptedSurname': encSurname,
        'encryptedTC': encTC,
        'encryptedChildName': encStudentName,
        'encryptedChildTC': encStudentTC,
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'parent'
      });

      // Telefona kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isParentLoggedIn', true);
      await prefs.setString('parentName', _nameController.text);

      setState(() {
        _isLoggedIn = true;
        _parentName = _nameController.text;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isParentLoggedIn');

    setState(() {
      _isLoggedIn = false;
      _nameController.clear();
      _surnameController.clear();
      _tcController.clear();
      _studentNameController.clear();
      _studentTcController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn) {
      return _buildDashboard();
    } else {
      return _buildRegistrationForm();
    }
  }

  // --- EKRAN TASARIMLARI (AYNI) ---
  Widget _buildDashboard() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        // --- BURASI EKLENDİ: Geri Dön Butonu ---
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context), // Veriyi silmeden geri döner
        ),
        // ---------------------------------------
        title: Text("Hoşgeldin, $_parentName", style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Bu kırmızı buton hala "Tamamen Çıkış" için duruyor
          IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: _handleLogout)
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 100, color: Colors.green.shade400),
            const SizedBox(height: 20),
            const Text(
              "Doğrulama Başarılı!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Öğrenci kaydı doğrulandı ve veli girişi yapıldı.\nÇocuğunuzun etkinliklerini buradan takip edebilirsiniz.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
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
                    Icon(Icons.security, size: 80, color: _primaryColor),
                    const SizedBox(height: 10),
                    Text("Veli Doğrulama", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _primaryColor)),
                    const Text("Güvenlik için öğrenci bilgilerini doğrulayın.", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(30),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Veli Bilgileri", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      _buildTextField(_nameController, "Adınız", Icons.person_outline),
                      const SizedBox(height: 15),
                      _buildTextField(_surnameController, "Soyadınız", Icons.badge_outlined),
                      const SizedBox(height: 15),
                      _buildTextField(_tcController, "TC Kimlik No", Icons.pin_outlined, isNumber: true),

                      const SizedBox(height: 25),
                      const Divider(thickness: 1.5),
                      const SizedBox(height: 10),

                      // --- ÖĞRENCİ DOĞRULAMA KISMI ---
                      Row(
                        children: [
                          Icon(Icons.verified_user, color: Colors.green.shade600, size: 20),
                          const SizedBox(width: 8),
                          const Text("Öğrenci Doğrulama", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text("Çocuğunuzun sisteme kayıtlı olduğu TC kimlik numarasını giriniz.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 15),

                      _buildTextField(_studentNameController, "Öğrencinin Adı", Icons.child_care),
                      const SizedBox(height: 15),
                      _buildTextField(_studentTcController, "Öğrencinin TC Kimlik No", Icons.password, isNumber: true),

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
                              : const Text("DOĞRULA VE GİRİŞ YAP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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