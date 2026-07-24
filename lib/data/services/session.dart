import 'package:shared_preferences/shared_preferences.dart';
import '../models/dealer_model.dart';

class Session {
  Session._();
  static final Session instance = Session._();

  static const _kUsername = 'username';
  static const _kDisplayName = 'display_name';

  String? username;
  String? displayName;

  bool get isLoggedIn => username != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString(_kUsername);
    displayName = prefs.getString(_kDisplayName);
  }

  Future<void> login(DealerModel dealer) async {
    username = dealer.username;
    displayName = dealer.displayName;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsername, dealer.username);
    await prefs.setString(_kDisplayName, dealer.displayName);
  }

  Future<void> logout() async {
    username = null;
    displayName = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUsername);
    await prefs.remove(_kDisplayName);
  }
}
