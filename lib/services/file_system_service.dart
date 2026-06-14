import 'dart:io';
import 'package:flutter/foundation.dart';

/// Read and write files in the project directory on the phone.
class FileSystemService {
  String? _projectPath;

  String? get projectPath => _projectPath;
  bool get hasProject => _projectPath != null;

  void setProject(String path) => _projectPath = path;

  List<FileSystemEntity> listFiles(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return [];
    return dir.listSync()..sort((a, b) => a.path.compareTo(b.path));
  }

  String readFile(String path) {
    try {
      return File(path).readAsStringSync();
    } catch (e) {
      return 'Error reading $path: $e';
    }
  }

  bool writeFile(String path, String content) {
    try {
      File(path).writeAsStringSync(content);
      return true;
    } catch (e) {
      debugPrint('Write failed: $e');
      return false;
    }
  }

  /// Run a shell command in the project directory.
  Future<String> runCommand(String command) async {
    if (_projectPath == null) return 'No project set.';
    try {
      final result = await Process.run(
        'sh', ['-c', command],
        workingDirectory: _projectPath,
        runInShell: true,
      );
      final out = (result.stdout as String).trim();
      final err = (result.stderr as String).trim();
      if (err.isNotEmpty && out.isEmpty) return err;
      return out;
    } catch (e) {
      return 'Command failed: $e';
    }
  }

  /// Git status shorthand.
  Future<String> gitStatus() => runCommand('git status --short');

  /// Git add all + commit.
  Future<String> gitCommit(String message) async {
    final add = await runCommand('git add -A');
    final commit = await runCommand('git commit -m "$message"');
    return 'add: $add\ncommit: $commit';
  }

  /// Git push.
  Future<String> gitPush() => runCommand('git push');
}
