import 'package:azure_devops/src/extensions/context_extension.dart';
import 'package:azure_devops/src/models/processes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class WorkItemTypeIcon extends StatelessWidget {
  const WorkItemTypeIcon({this.type, this.size = 20});

  final WorkItemType? type;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (type == null || type == WorkItemType.all) return const SizedBox();

    final colorQuery = type!.color != null ? 'color=${type!.color}&' : '';
    final api = context.api;
    final baseUrl = api.isOnPrem
        ? '${api.basePath}/_apis/wit/workItemIcons'
        : 'https://tfsprodweu2.visualstudio.com/_apis/wit/workItemIcons';
    final url = '$baseUrl/${type!.icon}?${colorQuery}v=2';
    return SvgPicture.network(url, width: size, headers: api.isOnPrem ? api.headers : null);
  }
}
