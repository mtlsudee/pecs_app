import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart'; // <--- 1. BU EKLENECEK

// Sayfaları import ediyoruz
import 'screens/teacherpage.dart';
import 'screens/studentpage.dart';
import 'screens/parentpage.dart';

// Main fonksiyonunu 'async' yapıyoruz çünkü Firebase'i bekleyeceğiz
void main() async {  // <--- 2. ASYNC EKLENECEK
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase'i başlatıyoruz
  await Firebase.initializeApp(); // <--- 3. BU SATIR EKLENECEK

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Role Selection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
      home: const RoleSelectionScreen(),
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD3EBF5),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              UserRoleCard(
                avatarColor: const Color(0xFFFFB347),
                avatarAsset: '👨🏻‍🎓',
                roleTitle: 'Öğrenci',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentPage(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 30),
              UserRoleCard(
                avatarColor: const Color(0xFFFFD89C),
                avatarAsset: '👩🏻',
                roleTitle: 'Ebeveyn',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ParentPage(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 30),
              UserRoleCard(
                avatarColor: const Color(0xFFC4B5FD),
                avatarAsset: '🧑🏻‍🏫',
                roleTitle: 'Öğretmen',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TeacherPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UserRoleCard extends StatelessWidget {
  final Color avatarColor;
  final String avatarAsset;
  final String roleTitle;
  final VoidCallback onTap;

  const UserRoleCard({
    Key? key,
    required this.avatarColor,
    required this.avatarAsset,
    required this.roleTitle,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 200,
        height: 220,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.lightBlue[100],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  avatarAsset,
                  style: const TextStyle(fontSize: 45),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              roleTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
          ],
        ),
      ),
    );
  }
}