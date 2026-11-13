import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../access.dart';
import '../config.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ryme entretien'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Courriel', icon: Icon(Icons.email_outlined)),
            Tab(text: 'Téléphone', icon: Icon(Icons.phone_android)),
          ]),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    Icon(Icons.directions_car_filled,
                        size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 8),
                    Text(
                      'Connectez-vous pour commencer votre essai gratuit de '
                      '${AppConfig.trialDays} jours.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(children: [_EmailTab(), _PhoneTab()]),
              ),
              if (AppConfig.privacyUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    'Politique de confidentialité : ${AppConfig.privacyUrl}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailTab extends StatefulWidget {
  const _EmailTab();

  @override
  State<_EmailTab> createState() => _EmailTabState();
}

class _EmailTabState extends State<_EmailTab> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _msg;
  bool _ok = false;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final access = context.read<AccessController>();
    if (_email.text.trim().isEmpty || _pw.text.isEmpty) {
      setState(() {
        _msg = 'Entrez votre courriel et votre mot de passe.';
        _ok = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    final err = _register
        ? await access.registerEmail(_email.text, _pw.text)
        : await access.signInEmail(_email.text, _pw.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = err;
      _ok = false;
    });
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      setState(() {
        _msg = "Entrez d'abord votre courriel.";
        _ok = false;
      });
      return;
    }
    final err = await context.read<AccessController>().resetPassword(_email.text);
    if (!mounted) return;
    setState(() {
      _msg = err ?? 'Courriel de réinitialisation envoyé.';
      _ok = err == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Courriel'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pw,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(
              labelText: 'Mot de passe', helperText: '6 caractères minimum'),
        ),
        if (_msg != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_msg!,
                style: TextStyle(
                    color: _ok
                        ? Colors.green.shade700
                        : Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_register ? 'Créer mon compte' : 'Se connecter'),
        ),
        TextButton(
          onPressed: () => setState(() {
            _register = !_register;
            _msg = null;
          }),
          child: Text(_register
              ? 'J\'ai déjà un compte'
              : 'Pas de compte ? Créer un compte'),
        ),
        if (!_register)
          TextButton(
              onPressed: _reset, child: const Text('Mot de passe oublié ?')),
      ],
    );
  }
}

class _PhoneTab extends StatefulWidget {
  const _PhoneTab();

  @override
  State<_PhoneTab> createState() => _PhoneTabState();
}

class _PhoneTabState extends State<_PhoneTab> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _msg;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Convertit en format international. 10 chiffres → Canada / États-Unis (+1).
  String? _normalize(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) {
      return digits.length >= 8 ? digits : null;
    }
    if (digits.length == 10) return '+1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return '+$digits';
    return null;
  }

  Future<void> _send({bool resend = false}) async {
    final phone = _normalize(_phone.text);
    if (phone == null) {
      setState(() => _msg =
          'Entrez un numéro valide (10 chiffres, ou format international +33…).');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    final err =
        await context.read<AccessController>().startPhone(phone, resend: resend);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = err;
    });
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    final err = await context.read<AccessController>().confirmCode(_code.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessController>();
    final sent = access.phoneCodeSent;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (!sent) ...[
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Numéro de téléphone',
              hintText: '514 555 0123',
              helperText:
                  'Un code par SMS vous sera envoyé. Des frais de votre opérateur peuvent s\'appliquer.',
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _send,
            child: const Text('Recevoir le code'),
          ),
        ] else ...[
          Text('Code envoyé au ${_phone.text}.'),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration:
                const InputDecoration(labelText: 'Code à 6 chiffres'),
          ),
          FilledButton(
            onPressed: _busy ? null : _confirm,
            child: const Text('Valider'),
          ),
          TextButton(
              onPressed: _busy ? null : () => _send(resend: true),
              child: const Text('Renvoyer le code')),
          TextButton(
              onPressed: access.resetPhoneFlow,
              child: const Text('Changer de numéro')),
        ],
        if (_msg != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_msg!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
