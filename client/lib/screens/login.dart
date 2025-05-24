import 'package:flutter/material.dart';
import 'package:bump_zone/network/websocket.dart';
import 'package:bump_zone/screens/game.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  late WebSocketService _webSocketService;
  String? _errorMessage;
  int _playerCount = 0;

  @override
  void initState() {
    super.initState();
    //Use ws://localhost:3000 for local testing
    _webSocketService = WebSocketService(
      'wss://lush-comet-icicle.glitch.me',
    );
    _webSocketService.connect();

    // Update player count from server
    _webSocketService.onPlayerListUpdate = (players) {
      setState(() {
        _playerCount = players.length;
      });
    };

    // Handle join response (welcome or error)
    _webSocketService.onStateUpdate = (players) {
      
      // Successful join, navigate to game screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(webSocketService: _webSocketService),
        ),
      );
      
    };

    // Handle connection errors
    _webSocketService.onError = (error) {
      print('WebSocket onError called with: $error (${error.runtimeType})');
      setState(() {
        _errorMessage =
            error == 'username_taken'
                ? 'Unavailable'
                : 'Failed to connect, try again';
      });
    };
  }

  @override
  void dispose() {
    _usernameController.dispose();
    //_webSocketService.disconnect();
    super.dispose();
  }

  void _joinGame() {
    final username = _usernameController.text.trim();
    if (username.isEmpty || username.length > 15) {
      setState(() {
        _errorMessage = 'Username must be 1-15 characters';
      });
      return;
    }

    // Send join message and wait for server response
    _webSocketService.join(username);
    // Server will respond with 'welcome' (navigate) or 'error' (show unavailable)
    _webSocketService.onError = (error) {
      setState(() {
        if (error == 'username_taken') {
          _errorMessage = 'Unavailable';
        }
      });
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Bump Zone',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Username',
                ),
                maxLength: 15,
              ),
              const SizedBox(height: 10),
              Text('Players online: $_playerCount'),
              const SizedBox(height: 10),
              if (_errorMessage != null)
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _joinGame();

                  /*
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => GameWidget(
                            username: _usernameController.text.trim(),
                          ),
                    ),
                  );
                  */

                },
                child: const Text('Join Game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
