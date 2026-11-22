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
    this.tenantId = 0,
    this.agentToken = '',
    this.iceServers = const [],
    this.locationMode = 'off',
    this.cameraAppOnly = false,
    this.displayName = '',
    this.companySlug = '',
  });

  final String token;
  final String company;
  final String extension;
  final String sipUsername;
  final Map<String, bool> permissions;
  final int tenantId;
  final String agentToken;
  final List<Map<String, dynamic>> iceServers;
  final String locationMode; // off | live | work_hours ...
  final bool cameraAppOnly;
  final String displayName;
  final String companySlug;

  bool can(String feature) => permissions[feature] ?? false;

  factory AppSession.fromLogin(Map<String, dynamic> res) {
    final perms = <String, bool>{};
    (res['permissions'] as Map?)?.forEach((k, v) => perms['$k'] = v == true);
    final ice = <Map<String, dynamic>>[];
    for (final e in (res['ice_servers'] as List? ?? const [])) {
      if (e is Map) ice.add(e.cast<String, dynamic>());
    }
    final settings = (res['settings'] as Map?)?.cast<String, dynamic>() ?? {};
    final tid = res['tenant_id'] ?? res['tenant']?['id'] ?? 0;
    return AppSession(
      token: res['token'] as String? ?? '',
      company: (res['tenant']?['company_name'] as String?) ?? '',
      extension: res['extension'] as String? ?? '',
      sipUsername: res['sip_username'] as String? ?? '',
      permissions: perms,
      tenantId: tid is int ? tid : int.tryParse('$tid') ?? 0,
      agentToken: res['agent_token'] as String? ?? '',
      iceServers: ice,
      locationMode: '${settings['location_mode'] ?? 'off'}',
      cameraAppOnly: settings['camera_app_only'] == true,
      displayName: res['extension'] as String? ?? '',
      companySlug: (res['tenant']?['company_slug'] as String?) ?? '',
    );
  }
}
