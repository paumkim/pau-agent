import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _tokenCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _tokenCtrl.text = prefs.getString('deepseek_token') ?? '';
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deepseek_token', _tokenCtrl.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 24),
          Text('Pau Agent Settings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          Text('DeepSeek API Token',
            style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _tokenCtrl,
            obscureText: true,
            decoration: InputDecoration(
              hintText: 'sk-...',
              helperText: 'Get your token from platform.deepseek.com',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
          const SizedBox(height: 32),
          Text('Commands',
            style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _cmd('/files', 'List files in the open project'),
          _cmd('/read <path>', 'View a file\'s contents'),
          _cmd('/git status', 'Check git status'),
          _cmd('/git add -A && git commit -m "msg"', 'Commit changes'),
          _cmd('/git push', 'Push to GitHub'),
        ],
      ),
    );
  }

  Widget _cmd(String cmd, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(cmd, style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Theme.of(context).colorScheme.primary,
            )),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(desc, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
