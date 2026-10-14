import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/verificacion_result_model.dart';
import '../services/auth_service.dart';
import '../services/chaira_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;
  final ChairaService _chairaService;

  AuthViewModel({AuthService? authService, ChairaService? chairaService})
      : _authService = authService ?? AuthService(),
        _chairaService = chairaService ?? ChairaService();

  bool _isLoading = false;
  bool _isVerifyingChaira = false;
  String? _errorMessage;
  VerificacionResult? _verificacionResult;

  // Getters para que las Vistas (Screens) lean el estado
  bool get isLoading => _isLoading;
  bool get isVerifyingChaira => _isVerifyingChaira;
  String? get errorMessage => _errorMessage;
  VerificacionResult? get verificacionResult => _verificacionResult;
  User? get currentUser => _authService.currentUser;

  /// Limpia errores o datos previos de Chaira (útil al salir de la pantalla de registro)
  void clearState() {
    _errorMessage = null;
    _verificacionResult = null;
    notifyListeners();
  }

  /// 1. Iniciar sesión con Firebase
  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final error = await _authService.signInWithEmailPassword(email, password);

    _isLoading = false;
    if (error != null) {
      _errorMessage = error;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  /// 2. Verificar cédula/documento en Chaira (para smart_register_screen)
  Future<bool> verificarEnChaira(String documento) async {
    _isVerifyingChaira = true;
    _errorMessage = null;
    _verificacionResult = null;
    notifyListeners();

    final result = await _chairaService.verificarDocumento(documento);

    _isVerifyingChaira = false;
    _verificacionResult = result;

    if (!result.success) {
      _errorMessage = result.error ?? 'No se pudo verificar el documento en Chaira.';
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  /// 3. Registrar usuario en Firebase
  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final error = await _authService.registerWithEmailPassword(email, password);

    _isLoading = false;
    if (error != null) {
      _errorMessage = error;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  /// 4. Recuperar contraseña
  Future<bool> recoverPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final error = await _authService.recoverPassword(email);

    _isLoading = false;
    if (error != null) {
      _errorMessage = error;
      notifyListeners();
      return false;
    }

    notifyListeners();
    return true;
  }

  /// 5. Cerrar sesión
  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }

  @override
  void dispose() {
    _chairaService.dispose();
    super.dispose();
  }
}