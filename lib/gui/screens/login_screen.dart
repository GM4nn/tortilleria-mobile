import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/dealer_model.dart';
import '../../data/services/session.dart';
import '../../data/services/dealer_service.dart';
import 'orders_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _dealerService = DealerService();
  final _pinController = TextEditingController();

  StreamSubscription<List<DealerModel>>? _dealersSub;
  List<DealerModel> _dealers = [];
  DealerModel? _selectedDealer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dealersSub = _dealerService.watchDealers().listen(
      _onDealers,
      onError: (_) => setState(() {
        _error = 'No se pudieron cargar los repartidores';
        _loading = false;
      }),
    );
  }

  @override
  void dispose() {
    _dealersSub?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _onDealers(List<DealerModel> dealers) {
    setState(() {
      _dealers = dealers;
      _loading = false;

      // Mantener la selección viva si el repartidor sigue existiendo
      if (_selectedDealer != null) {
        final match =
            dealers.where((d) => d.username == _selectedDealer!.username);
        _selectedDealer = match.isEmpty ? null : match.first;
      }
    });
  }

  Future<void> _login() async {
    final dealer = _selectedDealer;

    if (dealer == null) {
      setState(() => _error = 'Selecciona un repartidor');
      return;
    }

    if (_pinController.text != dealer.pin) {
      setState(() => _error = 'PIN incorrecto');
      return;
    }

    await Session.instance.login(dealer);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OrdersScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _loading
                ? const CircularProgressIndicator()
                : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🌽', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 8),
        Text(
          'Iniciar sesión',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 24),
        DropdownButtonFormField<DealerModel>(
          initialValue: _selectedDealer,
          decoration: const InputDecoration(
            labelText: 'Repartidor',
            border: OutlineInputBorder(),
          ),
          items: _dealers
              .map((d) => DropdownMenuItem(value: d, child: Text(d.displayName)))
              .toList(),
          onChanged: (d) => setState(() {
            _selectedDealer = d;
            _error = null;
          }),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'PIN',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _login(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _login,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Entrar'),
          ),
        ),
      ],
    );
  }
}
