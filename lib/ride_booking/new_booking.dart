import 'package:flutter/material.dart';
import 'package:premium_force_main/common_widgets/premiumdropdown.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';

class NewBooking extends StatefulWidget {
  final int catcode;
  final int citycode;
  const NewBooking({super.key, required this.catcode, required this.citycode});

  @override
  State<NewBooking> createState() => _NewBookingState();
}

class _NewBookingState extends State<NewBooking> {
  late int _selectedCatCode;
  late int _selectedCityCode;

  @override
  void initState() {
    super.initState();
    _selectedCatCode = widget.catcode;
    _selectedCityCode = widget.citycode;
  }

  String _getServiceName(BuildContext context, int code) {
    final loc = AppLocalizations.of(context)!;
    switch (code) {
      case 1:
        return loc.airportDeparture;
      case 2:
        return loc.chauffeurService;
      case 0:
      default:
        return loc.airportArrival;
    }
  }

  String _getCityName(BuildContext context, int code) {
    final loc = AppLocalizations.of(context)!;
    switch (code) {
      case 1:
        return loc.dammam;
      case 2:
        return loc.jeddah;
      case 0:
      default:
        return loc.riyadh;
    }
  }

  int _getCatCode(BuildContext context, String name) {
    final loc = AppLocalizations.of(context)!;
    if (name == loc.airportDeparture) return 1;
    if (name == loc.chauffeurService) return 2;
    return 0;
  }

  int _getCityCode(BuildContext context, String name) {
    final loc = AppLocalizations.of(context)!;
    if (name == loc.dammam) return 1;
    if (name == loc.jeddah) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff3E230A), Color(0xff141313)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        appBar: buidAppBar(context),
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildStepper(context),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                loc.tripInfo,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                loc.tellUsAboutYourJourney,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  // fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PremiumDropDown(
                title: loc.serviceType,
                value: _getServiceName(context, _selectedCatCode),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCatCode = _getCatCode(context, val);
                    });
                  }
                },
                items: [
                  loc.airportArrival,
                  loc.airportDeparture,
                  loc.chauffeurService,
                ],
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PremiumDropDown(
                title: loc.city,
                value: _getCityName(context, _selectedCityCode),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCityCode = _getCityCode(context, val);
                    });
                  }
                },
                items: [loc.riyadh, loc.jeddah, loc.dammam],
              ),
            ),
            SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      spacing: 5,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.airport,
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Container(
                          height: 54,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    "King Abdulaziz Intl. Airport",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    "Terminal 1",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildIncompleteCheckMark(BuildContext context) {
    return Icon(Icons.circle_outlined, color: Colors.grey.shade700, size: 20);
  }

  Widget buildCompletedCheckMark(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [Color(0xff49280B), Color(0xffE4A46B), Color(0xff60350F)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bounds),
      child: Icon(Icons.check_circle, color: Colors.white, size: 20),
    );
  }

  PreferredSizeWidget buidAppBar(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(100), Colors.transparent],
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            loc.newBooking,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            enableFeedback: true,
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Widget buildStepper(BuildContext context) {
    AppLocalizations loc = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(color: Colors.black.withAlpha(140)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              spacing: 5,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildIncompleteCheckMark(context),
                Text(
                  loc.tripInfo,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
            Expanded(
              child: Divider(
                color: Colors.grey.shade700,
                thickness: 1,
                indent: 20,
                endIndent: 20,
              ),
            ),
            Column(
              spacing: 5,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildIncompleteCheckMark(context),
                Text(
                  loc.preferences,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
            Expanded(
              child: Divider(
                color: Colors.grey.shade700,
                thickness: 1,
                indent: 20,
                endIndent: 20,
              ),
            ),
            Column(
              spacing: 5,
              mainAxisSize: MainAxisSize.min,
              children: [
                buildIncompleteCheckMark(context),
                Text(
                  loc.passenger,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
