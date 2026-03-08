import 'user.dart';

class AuthResponse {
  final String token;
  final User user;

  AuthResponse({
    required this.token,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    
    // Safety handling based on backend standard `{ success: true, data: { token, user } }` vs direct flattening
    final data = json['data'] ?? json;
    
    return AuthResponse(
      token: data['token'] as String,
      user: User.fromJson(data['user'] as Map<String, dynamic>),
    );
  }
}
