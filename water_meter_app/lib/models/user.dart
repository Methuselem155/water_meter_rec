import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String accountNumber;
  final String fullName;
  final String phoneNumber;
  final String? email;

  const User({
    required this.id,
    required this.accountNumber,
    required this.fullName,
    required this.phoneNumber,
    this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      accountNumber: json['accountNumber'] ?? '',
      fullName: json['fullName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountNumber': accountNumber,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'email': email,
    };
  }

  @override
  List<Object?> get props => [id, accountNumber, fullName, phoneNumber, email];
}
