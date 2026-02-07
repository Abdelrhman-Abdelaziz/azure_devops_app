part of login;

class _LoginScreen extends StatelessWidget {
  const _LoginScreen(this.ctrl, this.parameters);

  final _LoginController ctrl;
  final _LoginParameters parameters;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => AppRouter.askBeforeClosingApp(didPop: didPop),
      child: AppPage(
        init: () async => true,
        title: 'Az DevOps',
        builder: (_) => ValueListenableBuilder<bool>(
          valueListenable: ctrl.isOnPrem,
          builder: (context, isOnPrem, _) => Column(
            children: [
              Text(
                'Manage your Azure DevOps tasks on the go',
                style: context.textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w500,
                  fontFamily: AppTheme.defaultFont,
                ),
              ),
              const SizedBox(height: 20),
              _OnPremToggle(ctrl: ctrl, isOnPrem: isOnPrem),
              if (isOnPrem) ...[
                const SizedBox(height: 20),
                _OnPremSettings(ctrl: ctrl),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Text('Sign in with your Personal Access Token', style: context.textTheme.titleMedium)),
                  IconButton(onPressed: ctrl.showInfo, icon: Icon(Icons.info_outline)),
                ],
              ),
              const SizedBox(height: 10),
              Form(
                child: Column(
                  children: [
                    DevOpsFormField(
                      formFieldKey: ctrl.formFieldKey,
                      onChanged: ctrl.setPat,
                      hint: 'Personal Access Token',
                      maxLines: 1,
                      onFieldSubmitted: ctrl.login,
                    ),
                    Link(
                      uri: Uri.parse(
                        'https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate',
                      ),
                      builder: (_, link) => SizedBox(
                        height: 48,
                        child: InkWell(
                          onTap: link,
                          child: Row(
                            children: [
                              Text(
                                'How to create a PAT?',
                                style: context.textTheme.titleSmall!.copyWith(decoration: TextDecoration.underline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    LoadingButton(onPressed: ctrl.login, text: 'Submit'),
                  ],
                ),
              ),
              if (!isOnPrem) ...[
                const SizedBox(height: 50),
                Row(
                  children: [
                    Expanded(child: const Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('Or', style: context.textTheme.titleMedium),
                    ),
                    Expanded(child: const Divider()),
                  ],
                ),
                const SizedBox(height: 50),
                LoadingButton(onPressed: ctrl.loginWithMicrosoft, text: 'Sign in with Microsoft'),
              ],
              const SizedBox(height: 100),
              Link(
                uri: Uri.parse('https://github.com/PurpleSoftSrl/azure_devops_app'),
                builder: (_, link) => InkWell(
                  onTap: link,
                  child: Text.rich(
                    textAlign: TextAlign.center,
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Check out Az DevOps ',
                          style: context.textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w500,
                            fontFamily: AppTheme.defaultFont,
                          ),
                        ),
                        TextSpan(
                          text: 'GitHub repository',
                          style: context.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Link(
                uri: Uri.parse('https://www.purplesoft.io?utm_source=azdevops_app&utm_medium=app&utm_campaign=azdevops'),
                builder: (_, link) => InkWell(
                  onTap: () => ctrl.openPurplesoftWebsite(link),
                  child: Text.rich(
                    textAlign: TextAlign.center,
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Made with \u2764 by ',
                          style: context.textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.w500,
                            fontFamily: AppTheme.defaultFont,
                          ),
                        ),
                        TextSpan(
                          text: 'PurpleSoft Srl',
                          style: context.textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnPremToggle extends StatelessWidget {
  const _OnPremToggle({required this.ctrl, required this.isOnPrem});

  final _LoginController ctrl;
  final bool isOnPrem;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: context.colorScheme.surface,
      ),
      child: SwitchListTile(
        title: Text('On-Premises Server', style: context.textTheme.titleSmall),
        subtitle: Text(
          isOnPrem ? 'Azure DevOps Server' : 'Azure DevOps Services (cloud)',
          style: context.textTheme.bodySmall,
        ),
        value: isOnPrem,
        onChanged: ctrl.toggleOnPrem,
        dense: true,
      ),
    );
  }
}

class _OnPremSettings extends StatefulWidget {
  const _OnPremSettings({required this.ctrl});

  final _LoginController ctrl;

  @override
  State<_OnPremSettings> createState() => _OnPremSettingsState();
}

class _OnPremSettingsState extends State<_OnPremSettings> {
  String _selectedVersion = '7.0';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: context.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Server URL', style: context.textTheme.titleSmall),
          const SizedBox(height: 8),
          DevOpsFormField(
            formFieldKey: widget.ctrl.serverUrlFormFieldKey,
            onChanged: widget.ctrl.setServerUrl,
            hint: 'https://tfs.company.com/tfs/DefaultCollection',
            maxLines: 1,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('API Version', style: context.textTheme.titleSmall),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedVersion,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: _LoginController.apiVersions
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedVersion = value);
                      widget.ctrl.setApiVersion(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
