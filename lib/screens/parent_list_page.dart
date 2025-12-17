import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/security_service.dart'; // Şifre çözücü

class ParentListPage extends StatelessWidget {
  const ParentListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0), // Ebeveyn için turuncu tonlarında arka plan
      appBar: AppBar(
        title: const Text("Kayıtlı Ebeveynler", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.orangeAccent),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // DİKKAT: Burada 'parents' koleksiyonunu dinliyoruz
        stream: FirebaseFirestore.instance
            .collection('parents')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 1. Yükleniyor mu?
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }

          // 2. Hata var mı?
          if (snapshot.hasError) {
            return Center(child: Text("Bir hata oluştu: ${snapshot.error}"));
          }

          // 3. Veri yok mu?
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.family_restroom, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  const Text("Henüz kayıtlı ebeveyn yok.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              // --- ŞİFRE ÇÖZME ---
              String name = "---";
              String surname = "";
              String tc = "";
              // String studentName = ""; // İleride ebeveynin çocuğunun adını da ekleyebiliriz

              try {
                name = SecurityService.decryptData(data['encryptedName']);
                surname = SecurityService.decryptData(data['encryptedSurname']);
                tc = SecurityService.decryptData(data['encryptedTC']);
              } catch (e) {
                name = "Veri Hatası";
              }

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  leading: CircleAvatar(
                    backgroundColor: Colors.orangeAccent.withOpacity(0.2),
                    child: Icon(Icons.person, color: Colors.orangeAccent),
                  ),
                  title: Text(
                    "$name $surname",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text("TC: $tc", style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    // Detay gerekirse buraya eklenecek
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