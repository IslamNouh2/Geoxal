class AppConfig {
  static const String databaseProvider = 'MSDASQL.1';
  static const String databaseDataSource = 'GEOXAL';
  static const String databaseUserId = 'SYSDBA';
  static const String databasePassword = 'masterkey';
  static const bool persistSecurityInfo = true;

  // Formats connection string based on the user provided format
  static String get odbcConnectionString {
    return 'Provider=$databaseProvider;Password=$databasePassword;Persist Security Info=$persistSecurityInfo;User ID=$databaseUserId;Data Source=$databaseDataSource';
  }
}
