import 'package:flutter/material.dart';
import '../../services/settings_service.dart';

class PasswordSettingsPage extends StatefulWidget {
  const PasswordSettingsPage({super.key});

  @override
  State<PasswordSettingsPage> createState() => _PasswordSettingsPageState();
}

class _PasswordSettingsPageState extends State<PasswordSettingsPage> {
  final _oldPwdController = TextEditingController();
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();
  bool _hasPassword = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _oldPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final has = await SettingsService.instance.hasPassword();
    if (mounted) {
      setState(() => _hasPassword = has);
    }
  }

  Future<void> _save() async {
    final newPwd = _newPwdController.text.trim();
    final confirmPwd = _confirmPwdController.text.trim();

    if (newPwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入新密码')),
      );
      return;
    }
    if (newPwd != confirmPwd) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('两次输入的密码不一致')),
      );
      return;
    }

    if (_hasPassword) {
      final oldPwd = _oldPwdController.text.trim();
      final isValid = await SettingsService.instance.verifyPassword(oldPwd);
      if (!isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('原密码错误')),
          );
        }
        return;
      }
    }

    await SettingsService.instance.setPassword(newPwd);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码设置成功')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _removePassword() async {
    if (_hasPassword) {
      final oldPwd = _oldPwdController.text.trim();
      final isValid = await SettingsService.instance.verifyPassword(oldPwd);
      if (!isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请输入正确的原密码')),
          );
        }
        return;
      }
    }
    await SettingsService.instance.removePassword();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码已取消')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('密码管理'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _hasPassword ? Icons.lock : Icons.lock_open,
                      color: _hasPassword ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(_hasPassword ? '密码保护已开启' : '密码保护未开启'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_hasPassword) ...[
              TextField(
                controller: _oldPwdController,
                obscureText: _obscureOld,
                decoration: InputDecoration(
                  labelText: '原密码',
                  prefixIcon: const Icon(Icons.vpn_key),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureOld ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureOld = !_obscureOld),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _newPwdController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: _hasPassword ? '新密码' : '设置密码',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPwdController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: '确认密码',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('保存密码'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
            if (_hasPassword) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _removePassword,
                icon: const Icon(Icons.lock_open, color: Colors.red),
                label: const Text('取消密码保护', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
