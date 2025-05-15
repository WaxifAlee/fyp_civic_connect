class ReportIdGenerator {
  static String getCategoryPrefix(String category) {
    // Map categories to their prefixes
    final Map<String, String> categoryPrefixes = {
      'Municipal Corporation': 'MC',
      'Police Department': 'PD',
      'Water Supply': 'WS',
      'Electricity': 'EL',
      'Roads & Infrastructure': 'RI',
      'Sanitation': 'SN',
      'Public Health': 'PH',
      'Environment': 'EV',
      // Add more categories as needed
    };

    return categoryPrefixes[category] ??
        'GN'; // GN for General if category not found
  }

  static String formatReportNumber(int number) {
    // Convert the number to a 5-digit string with leading zeros
    return number.toString().padLeft(5, '0');
  }

  static String generateReportId(String category, int sequenceNumber) {
    final prefix = getCategoryPrefix(category);
    final number = formatReportNumber(sequenceNumber);
    return '$prefix$number';
  }
}
