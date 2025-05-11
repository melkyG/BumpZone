import 'package:flutter/material.dart';
import 'game_widget.dart'; // Import the GameWidget

class MenuWidget extends StatelessWidget {
  const MenuWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title
                  const Padding(
                    padding: EdgeInsets.only(top: 20, bottom: 40),
                    child: Text(
                      'BumpZone',
                      style: TextStyle(
                        fontSize: 36, // Smaller for minimalism
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  // Menu buttons
                  Column(
                    children: [
                      // Single Player Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, // Black background
                          foregroundColor: Colors.white, // White text
                          minimumSize: const Size(200, 50), // Smaller size
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              8,
                            ), // Subtle rounding
                          ),
                          elevation: 0, // Flat for minimalism
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const GameWidget(),
                            ),
                          );
                        },
                        child: const Text(
                          'Single Player',
                          style: TextStyle(
                            fontSize: 18, // Smaller text
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16), // Reduced spacing
                      // Multiplayer Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, // Black background
                          foregroundColor: Colors.white, // White text
                          minimumSize: const Size(200, 50), // Smaller size
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0, // Flat for minimalism
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          // TODO: Implement multiplayer navigation
                        },
                        child: const Text(
                          'Multiplayer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Settings gear
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(
                  Icons.settings,
                  color: Colors.black, // Black to match minimalist theme
                  size: 24, // Smaller for minimalism
                ),
                onPressed: () {
                  // TODO: Implement settings navigation
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
