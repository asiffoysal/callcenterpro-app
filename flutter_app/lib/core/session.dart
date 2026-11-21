/// The signed-in agent session: token, identity and the feature permissions
/// the server returned in /app/v1/login. Screens read [can] to hide anything
/// the admin turned off for this agent.
class AppSession {
  AppSession({
    required this.token,
    required this.company,
    required this.extension,
    required this.sipUsername,
    required this.permissions,
  });

  final String token;
  final String company;
  final String extension;
  final String sipUsername;
  final Map<String, bool> permissions;

  bool can(String feature) => permissions[feature] ?? false;

  factory AppSession.fromLogin(Map<String, dynamic> res) {
    final perms = <String, bool>{};
    (res['permissions'] as Map?)?.forEach((k, v) => perms['$k'] = v == true);
    return AppSession(
      token: res['token'] as String? ?? '',
      company: (res['tenant']?['company_name'] as String?) ?? '',
      extension: res['extension'] as String? ?? '',
      sipUsername: res['sip_username'] as String? ?? '',
      permissions: perms,
    );
  }
}
