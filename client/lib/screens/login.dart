import 'package:flutter/material.dart';
import 'package:bump_zone/network/websocket.dart';
import 'package:bump_zone/screens/game.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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
  bool _joining = false;
  Color _selectedColor = Colors.blue;

  @override
  void initState() {
    super.initState();

    _webSocketService = WebSocketService(
      'wss://thorn-glory-wanderer.glitch.me',
    );

    // Set all callbacks BEFORE connect()
    _webSocketService.onPlayerListUpdate = (players) {
      setState(() {
        _playerCount = players.length;
      });
      if (_joining && _errorMessage == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GameScreen(webSocketService: _webSocketService),
          ),
        );
      }
    };

    _webSocketService.onError = (error) {
      if (!_joining) return;
      print('WebSocket onError called with: $error');
      setState(() {
        _joining = false;
        _errorMessage = error == 'username_taken'
            ? 'Username unavailable'
            : 'Failed to connect, try again';
      });
    };

    // Add this:
    _webSocketService.onWelcome = (playerId) {
      print('[LOGIN] onWelcome: $playerId');
      _webSocketService.sendRaw({'type': 'getBandSettings'});
    };

    _webSocketService.connect();

    Future.delayed(const Duration(milliseconds: 100), () {
      _webSocketService.requestPlayerList();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    // Do not disconnect the WebSocket here to allow reuse in GameScreen
    super.dispose();
  }

  void _joinGame() {
    final username = _usernameController.text.trim();
    if (username.isEmpty || username.length > 20) {
      setState(() {
        _errorMessage = 'Username must be 1-20 characters';
      });
      return;
    }
    setState(() {
      _errorMessage = null;
      _joining = true;
    });

    // Send join request and include color as hex string
    _webSocketService.sendRaw({
      'type': 'join',
      'username': username,
      'color': '#${_selectedColor.value.toRadixString(16).padLeft(8, '0')}',
    });
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
                maxLength: 20,
              ),
              const SizedBox(height: 10),
              // Ball color picker
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Ball Color:'),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      Color? picked = await showDialog<Color>(
                        context: context,
                        builder: (context) {
                          Color tempColor = _selectedColor;
                          return AlertDialog(
                            title: const Text('Pick Ball Color'),
                            content: SingleChildScrollView(
                              child: BlockPicker(
                                pickerColor: tempColor,
                                onColorChanged: (color) {
                                  tempColor = color;
                                },
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(tempColor),
                                child: const Text('Select'),
                              ),
                            ],
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedColor = picked;
                        });
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('Players online: $_playerCount'),
              const SizedBox(height: 10),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _joining ? null : _joinGame,
                child: const Text('Join Game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
