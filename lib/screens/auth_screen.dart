import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../access.dart';
import '../config.dart';

/// Ouverture de compte et connexion : par courriel et mot de passe seulement.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _register = true;
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ryme entretien')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(Icons.directions_car_filled, size: 56, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              _register
                  ? (AppConfig.nativeTrial
                      ? 'Créez votre compte avec votre courriel. Un essai '
                          'gratuit de ${AppConfig.trialDays} jours vous sera '
                          'proposé ensuite.'
                      : 'Créez votre compte avec votre courriel pour commencer '
                          'votre essai gratuit de ${AppConfig.trialDays} jours.')
                  : 'Connectez-vous avec votre courriel.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
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
                  labelText: 'Mot de passe',
                  helperText: '6 caractères minimum'),
            ),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_msg!,
                    style: TextStyle(
                        color: _ok ? Colors.green.shade700 : scheme.error)),
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
                  ? "J'ai déjà un compte"
                  : 'Pas de compte ? Créer un compte'),
            ),
            if (!_register)
              TextButton(
                  onPressed: _reset,
                  child: const Text('Mot de passe oublié ?')),
            if (AppConfig.privacyUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SelectableText(
                  'Politique de confidentialité : ${AppConfig.privacyUrl}',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
