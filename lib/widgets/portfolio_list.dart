// lib/widgets/portfolio_list.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/stock_detail_screen.dart';

class PortfolioList extends StatelessWidget {
  const PortfolioList({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
            child: Text('Your portfolio is empty. Add a stock to get started!'),
          );
        }
        
        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final portfolio = (userData['portfolio'] as List<dynamic>?)?.cast<String>() ?? [];

        if (portfolio.isEmpty) {
          return const Center(
            child: Text('Your portfolio is empty. Add a stock to get started!'),
          );
        }

        return ListView.builder(
          itemCount: portfolio.length,
          itemBuilder: (ctx, index) {
            final stockSymbol = portfolio[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
              child: ListTile(
                // --- THIS IS THE MISSING CODE ---
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => StockDetailScreen(stockSymbol: stockSymbol),
                    ),
                  );
                },
                // ---------------------------------
                title: Text(
                  stockSymbol,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                      'portfolio': FieldValue.arrayRemove([stockSymbol]),
                    });
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}