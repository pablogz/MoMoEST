import 'package:flutter/material.dart';
import 'package:momoest/l10n/generated/app_localizations.dart';
import 'package:momoest/util/auxiliar.dart';

class StudyInfo extends StatelessWidget {
  const StudyInfo({super.key});

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    double lateralMargin =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(appLoca.studyInfoTitle,
                overflow: TextOverflow.ellipsis, maxLines: 1),
            centerTitle: false,
            pinned: true,
          ),
          SliverPadding(
            padding:
                EdgeInsets.symmetric(horizontal: lateralMargin, vertical: 20),
            sliver: SliverSafeArea(
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints:
                        const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section(context, "", appLoca.studyInfoIntro),
                        _section(context, appLoca.studyInfoSectionA,
                            appLoca.studyInfoTextA),
                        _section(context, appLoca.studyInfoSectionB,
                            appLoca.studyInfoTextB),
                        _section(context, appLoca.studyInfoSectionC,
                            appLoca.studyInfoTextC),
                        _section(context, appLoca.studyInfoSectionD,
                            appLoca.studyInfoTextD),
                        _section(context, appLoca.studyInfoSectionE,
                            appLoca.studyInfoTextE),
                        _section(context, appLoca.studyInfoSectionG,
                            appLoca.studyInfoTextG),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, String content) {
    TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style:
                  textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
          if (title.isNotEmpty) const SizedBox(height: 8),
          Text(content, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
