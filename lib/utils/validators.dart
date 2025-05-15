class Validators {
  static final RegExp _passwordRegex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,64}$');

  static final RegExp _phoneRegex = RegExp(r'^\+92(3[0-9]{9})$');

  static final RegExp _cnicRegex =
      RegExp(r'^\d{5}-\d{7}-\d{1}$' // Pakistani CNIC format
          );

  static final RegExp _emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  static final RegExp _nameRegex =
      RegExp(r'^[a-zA-Z\s]{3,100}$' // Only letters and spaces, 3-100 chars
          );

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (value.length > 64) {
      return 'Password must not exceed 64 characters';
    }
    if (!_passwordRegex.hasMatch(value)) {
      return 'Password must contain uppercase, lowercase, number and special character';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (!_phoneRegex.hasMatch(value)) {
      return 'Enter valid international format: +923001234567';
    }
    return null;
  }

  static String? validateCNIC(String? value) {
    if (value == null || value.isEmpty) {
      return 'CNIC is required';
    }
    if (!_cnicRegex.hasMatch(value)) {
      return 'Enter valid CNIC format: 12345-1234567-1';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    // Sanitize email
    value = value.trim().toLowerCase();
    if (!_emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (!_nameRegex.hasMatch(value)) {
      return 'Name can only contain letters and must be under 100 characters';
    }
    return null;
  }
}
