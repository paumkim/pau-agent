import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/deepseek_service.dart';
import '../services/file_system_service.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _service = DeepSeekService();
  final _fs = FileSystemService();
  final List<_Message> _messages = [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadToken();
    _messages.add(_Message(
      'Hi, I\'m Pau Agent. I can help you code from your phone.\n\n'
      'Try: "show me the files in this project" or "edit the home screen"',
      isUser: false,
    ));
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('deepseek_token') ?? '';
    if (token.isNotEmpty) {
      _service.setToken(token);
    }
  }

  @override
  void dispose() {
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _chatCtrl.clear();

    setState(() {
      _messages.add(_Message(text, isUser: true));
      _sending = true;
    });

    // Check for file system commands
    if (text.startsWith('/')) {
      await _handleCommand(text);
      setState(() => _sending = false);
      return;
    }

    // Normal chat with AI
    final msgs = _messages
        .where((m) => m.text.isNotEmpty)
        .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
        .toList();

    final buffer = StringBuffer();
    await for (final chunk in _service.chat(messages: msgs)) {
      buffer.write(chunk);
      setState(() {
        if (_messages.isNotEmpty && !_messages.last.isUser) {
          _messages.last = _Message(buffer.toString(), isUser: false);
        } else {
          _messages.add(_Message(buffer.toString(), isUser: false));
        }
      });
      _scrollDown();
    }
    setState(() => _sending = false);
  }

  Future<void> _handleCommand(String cmd) async {
    final parts = cmd.split(' ');
    final response = switch (parts[0]) {
      '/files' => _handleFiles(parts),
      '/read' => _handleRead(parts),
      '/edit' => _handleEdit(cmd),
      '/git' => await _handleGit(cmd),
      _ => 'Unknown command. Try: /files, /read <path>, /edit, /git status',
    };
    setState(() => _messages.add(_Message(response, isUser: false)));
    _scrollDown();
  }

  String _handleFiles(List<String> parts) {
    if (!_fs.hasProject) return 'No project loaded. Use Settings to set a project path.';
    final path = parts.length > 1 ? parts.sublist(1).join(' ').trim() : _fs.projectPath!;
    final files = _fs.listFiles(path);
    if (files.isEmpty) return 'Empty directory.';
    return files.map((f) {
      final name = f.path.split('/').last;
      final isDir = FileSystemEntity.isDirectorySync(f.path);
      final icon = isDir ? '📁' : '📄';
      return '$icon $name';
    }).join('\n');
  }

  String _handleRead(List<String> parts) {
    if (parts.length < 2) return 'Usage: /read <filepath>';
    final content = _fs.readFile(parts[1]);
    return '```\n$content\n```';
  }

  String _handleEdit(String cmd) {
    return 'Edit mode: send the full file path and new content.\n'
        'Example: "update lib/main.dart to show a different title"';
  }

  Future<String> _handleGit(String cmd) async {
    if (!_fs.hasProject) return 'No project loaded.';
    return await _fs.runCommand(cmd.substring(5).trim());
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openFilePicker() async {
    // Simple file selection for now
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      _fs.setProject(result);
      setState(() => _messages.add(_Message(
        '📂 Project loaded: $result\n\nTry: /files to see your files',
        isUser: false,
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 12),
            child: Row(
              children: [
                Icon(Icons.smart_toy, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Pau Agent',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (!_fs.hasProject)
                  TextButton.icon(
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Open', style: TextStyle(fontSize: 12)),
                    onPressed: _openFilePicker,
                  ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? Theme.of(context).colorScheme.primary.withAlpha(30)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(msg.text, style: const TextStyle(height: 1.5, fontSize: 14)),
                  ),
                );
              },
            ),
          ),
          // Input
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatCtrl,
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Ask me to code something...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  onPressed: _sending ? null : _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message {
  final String text;
  final bool isUser;
  _Message(this.text, {required this.isUser});
}
