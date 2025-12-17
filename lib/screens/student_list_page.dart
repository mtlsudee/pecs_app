import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/security_service.dart'; // Şifre Çözücü Servisimiz

class StudentListPage extends StatelessWidget {
  const StudentListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5), // Öğretmen teması (Mor açık)
      appBar: AppBar(
        title: const Text("Kayıtlı Öğrenciler", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 'students' koleksiyonunu dinliyoruz
        stream: FirebaseFirestore.instance
            .collection('students')
            .orderBy('createdAt', descending: true) // En yeni kayıt en üstte
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Yükleniyor durumu
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Hata durumu
          if (snapshot.hasError) {
            return Center(child: Text("Bir hata oluştu: ${snapshot.error}"));
          }

          // 3. Veri yoksa
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "Henüz kayıtlı öğrenci yok.",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          // 4. Verileri Listele
          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              // --- ŞİFRE ÇÖZME İŞLEMİ (CRITICAL PART) ---
              String name = "Veri Hatası";
              String surname = "";
              String tc = "";

              try {
                // Veritabanındaki şifreli veriyi (encryptedName) alıp çözüyoruz
                if (data['encryptedName'] != null) {
                  name = SecurityService.decryptData(data['encryptedName']);
                }
                if (data['encryptedSurname'] != null) {
                  surname = SecurityService.decryptData(data['encryptedSurname']);
                }
                if (data['encryptedTC'] != null) {
                  tc = SecurityService.decryptData(data['encryptedTC']);
                }
              } catch (e) {
                print("Şifre çözme hatası: $e");
              }
              // -------------------------------------------

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : "?",
                      style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    "$name $surname",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        const Icon(Icons.pin_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text("TC: $tc", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    // İleride detay sayfasına gitmek istersen burayı kullanabilirsin
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("$name seçildi")),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}