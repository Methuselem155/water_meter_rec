class LoginRequest {
  final String? phoneNumber;
  final String? accountNumber;
  final String password;

  LoginRequest({
    this.phoneNumber,
    this.accountNumber,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {'password': password};
    // Include only provided identifiers
    if (phoneNumber != null && phoneNumber!.isNotEmpty) {
      data['phoneNumber'] = phoneNumber;
    } else if (accountNumber != null && accountNumber!.isNotEmpty) {
      data['accountNumber'] = accountNumber;
    }
    return data;
  }
}

class RegisterRequest {
  final String accountNumber;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final String password;
  final String meterSerialNumber;
  final String category;

  RegisterRequest({
    required this.accountNumber,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    required this.password,
    required this.meterSerialNumber,
    required this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'accountNumber': accountNumber,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'email': email,
      'password': password,
      'meterSerialNumber': meterSerialNumber,
      'category': category,
    };
  }
}
