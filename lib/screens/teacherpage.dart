import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/security_service.dart'; // Şifre çözmek için gerekli

class TeacherPage extends StatelessWidget {
  const TeacherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Öğretmen Paneli"),
        backgroundColor: const Color(0xFFC4B5FD),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Firebase'deki 'students' tablosunu dinliyoruz
        stream: FirebaseFirestore.instance.collection('students').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {

          // 1. Veri yükleniyor mu?
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Hata var mı?
          if (snapshot.hasError) {
            return Center(child: Text("Hata oluştu: ${snapshot.error}"));
          }

          // 3. Veri yok mu?
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Henüz kayıtlı öğrenci yok."));
          }

          // 4. Verileri Listele
          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              // --- KRİTİK: Şifreli veriyi çözüyoruz (Decrypt) ---
              // Eğer veritabanında şifresiz veri varsa hata vermesin diye try-catch kullanıyoruz
              String name = "Bilinmiyor";
              String surname = "";
              String tc = "";

              try {
                name = SecurityService.decryptData(data['encryptedName']);
                surname = SecurityService.decryptData(data['encryptedSurname']);
                tc = SecurityService.decryptData(data['encryptedTC']);
              } catch (e) {
                name = "Şifre Çözülemedi"; // Eski veya bozuk veri
              }

              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFC4B5FD),
                    child: Text(name.isNotEmpty ? name[0] : "?", style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text("$name $surname", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("TC: $tc"),
                      Text("Kayıt: ${data['deviceSource'] ?? 'Bilinmiyor'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}