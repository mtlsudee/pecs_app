import 'package:flutter/material.dart';

class ParentPage extends StatelessWidget {
  const ParentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ebeveyn Ekranı")),
      body: const Center(
        child: Text(
          "Buraya Ebeveyn ekranı gelecek",
          style: TextStyle(fontSize: 28),
        ),
      ),
    );
  }
}