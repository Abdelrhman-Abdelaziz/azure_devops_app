part of login;

class _LoginController with AppLogger {
  _LoginController._(this.api, this.storage);

  final StorageService storage;
  final AzureApiService api;

  final formFieldKey = GlobalKey<FormFieldState<dynamic>>();
  final serverUrlFormFieldKey = GlobalKey<FormFieldState<dynamic>>();

  String pat = '';

  final isOnPrem = ValueNotifier(false);
  String serverUrl = '';
  String selectedApiVersion = '7.0';

  static const apiVersions = ['5.0', '5.1', '6.0', '7.0'];

  // ignore: use_setters_to_change_properties
  void setPat(String value) {
    pat = value;
  }

  void toggleOnPrem(bool value) {
    isOnPrem.value = value;
  }

  // ignore: use_setters_to_change_properties
  void setServerUrl(String value) {
    serverUrl = value;
  }

  void setApiVersion(String version) {
    selectedApiVersion = version;
  }

  Future<void> loginWithMicrosoft() async {
    final loginRes = await MsalService().login();
    if (loginRes == null) return;

    await _loginAndNavigate(loginRes, isPat: false);
  }

  Future<void> login() async {
    final isValid = formFieldKey.currentState!.validate();
    if (!isValid) return;

    if (isOnPrem.value) {
      if (serverUrl.isEmpty) {
        OverlayService.error('Server URL required', description: 'Please enter your Azure DevOps Server URL');
        return;
      }

      // Validate URL format
      final uri = Uri.tryParse(serverUrl);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        OverlayService.error(
          'Invalid URL',
          description: 'Please enter a valid URL (e.g. https://tfs.company.com/tfs/DefaultCollection)',
        );
        return;
      }

      await api.setOnPremConfig(isOnPrem: true, serverUrl: serverUrl, apiVersion: selectedApiVersion);
    } else {
      await api.setOnPremConfig(isOnPrem: false, serverUrl: '', apiVersion: '7.0');
    }

    await _loginAndNavigate(LoginResponse(accessToken: pat, tenantId: ''), isPat: true);
  }

  Future<void> _loginAndNavigate(LoginResponse loginResponse, {required bool isPat}) async {
    final isLogged = await api.login(loginResponse.accessToken);

    final isFailed = [LoginStatus.failed, LoginStatus.unauthorized].contains(isLogged);

    logAnalytics('signin_with_${isPat ? 'pat' : 'microsoft'}_${isOnPrem.value ? 'onprem_' : ''}${isFailed ? 'failed' : 'success'}', {});

    if (isLogged == LoginStatus.failed) {
      _showLoginErrorAlert();
      return;
    }

    if (isLogged == LoginStatus.unauthorized) {
      if (isOnPrem.value) {
        // On-prem doesn't have org concept, show auth error directly
        _showLoginErrorAlert();
        return;
      }

      final hasSetOrg = await _setOrgManually();
      if (!hasSetOrg) return;

      final isLoggedManually = await api.login(pat);
      if (isLoggedManually == LoginStatus.failed) {
        _showLoginErrorAlert();
        return;
      } else if (isLoggedManually == LoginStatus.unauthorized) {
        _showLoginErrorAlert();
        return;
      }
    }

    storage.setTenantId(loginResponse.tenantId);

    await AppRouter.goToChooseProjects();
  }

  void showInfo() {
    OverlayService.error(
      'Info',
      description:
          'Your PAT is stored on your device and is only used as an http header to communicate with Azure API, '
          "it's not stored anywhere else.\n\n"
          "Check that your PAT has 'User Profile' read enabled, otherwise it won't work.",
    );
  }

  void _showLoginErrorAlert() {
    if (isOnPrem.value) {
      OverlayService.error(
        'Login error',
        description: 'Check that your PAT and Server URL are correct and retry',
      );
    } else {
      OverlayService.error('Login error', description: 'Check that your PAT is correct and retry');
    }
  }

  Future<bool> _setOrgManually() async {
    var hasSetOrg = false;

    String? manualOrg;
    await OverlayService.bottomsheet(
      title: 'Insert your organization',
      isScrollControlled: true,
      builder: (context) => Column(
        children: [
          DevOpsFormField(
            label: 'Organization',
            onChanged: (s) => manualOrg = s,
            onFieldSubmitted: () {
              hasSetOrg = true;
              AppRouter.pop();
            },
            maxLines: 1,
          ),
          const SizedBox(height: 40),
          LoadingButton(
            onPressed: () {
              hasSetOrg = true;
              AppRouter.pop();
            },
            text: 'Confirm',
          ),
        ],
      ),
    );

    if (!hasSetOrg) return false;
    if (manualOrg == null || manualOrg!.isEmpty) return false;

    await api.setOrganization(manualOrg!);

    return true;
  }

  void openPurplesoftWebsite(FollowLink? link) {
    logInfo('Open Purplesoft website');

    link?.call();
  }
}
