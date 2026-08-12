import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import 'home_page.dart';

class LockScreenPage extends StatefulWidget {
  const LockScreenPage({super.key});

  @override
  State<LockScreenPage> createState() => _LockScreenPageState();
}

class _LockScreenPageState extends State<LockScreenPage> {
  final _pwdController = TextEditingController();
  bool _obscure = true;
  String? _errorMsg;
  bool _loading = true;
  bool _hasPassword = false;

  @override
  void initState() {
    super.initState();
    _checkPassword();
  }

  @override
  void dispose() {
    _pwdController.dispose();
    super.dispose();
  }

  Future<void> _checkPassword() async {
    final has = await SettingsService.instance.hasPassword();
    if (mounted) {
      if (!has) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        setState(() {
          _hasPassword = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _unlock() async {
    final pwd = _pwdController.text.trim();
    if (pwd.isEmpty) {
      setState(() => _errorMsg = '请输入密码');
      return;
    }
    final valid = await SettingsService.instance.verifyPassword(pwd);
    if (valid) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } else {
      setState(() {
        _errorMsg = '密码错误';
        _pwdController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: colorScheme.primary)),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '学习进度',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请输入密码以继续',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _pwdController,
                  obscureText: _obscure,
                  onSubmitted: (_) => _unlock(),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: '密码',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: const OutlineInputBorder(),
                    errorText: _errorMsg,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _unlock,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('解锁'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
