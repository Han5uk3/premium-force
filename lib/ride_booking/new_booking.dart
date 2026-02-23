import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/premiumdropdown.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/common_widgets/textfield.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/authentication/location_picker.dart';

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

  final _formKey = GlobalKey<FormState>();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  DateTime? _selectedPickupDate;
  TimeOfDay? _selectedPickupTime;

  String? _dropAddress;
  double? _dropLat;
  double? _dropLng;
  String? _pickupAddress;
  double? _pickupLat;
  double? _pickupLng;

  TextEditingController flightNumberController = TextEditingController();
  int _selectedTerminalCode = 0;

  List<String> _getTerminals(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (_selectedCityCode == 1) {
      // Dammam
      return [loc.passengerTerminal, loc.aramcoTerminal, loc.royalTerminal];
    } else if (_selectedCityCode == 2) {
      // Jeddah
      return [
        loc.terminal1,
        loc.hajjTerminal,
        loc.northTerminal,
        loc.southTerminal,
      ];
    } else {
      // Riyadh
      return [
        loc.terminal1,
        loc.terminal2,
        loc.terminal3,
        loc.terminal4,
        loc.terminal5,
      ];
    }
  }

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
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
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
                          _selectedTerminalCode = 0;
                        });
                      }
                    },
                    items: [loc.riyadh, loc.jeddah, loc.dammam],
                  ),
                ),
                SizedBox(height: 16),

                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.05),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                    child: Builder(
                      key: ValueKey<int>(_selectedCatCode),
                      builder: (context) {
                        if (_selectedCatCode == 0)
                          return buildArrivalSection(context, loc);
                        if (_selectedCatCode == 1)
                          return buildDepartureSection(context, loc);
                        if (_selectedCatCode == 2)
                          return buildChauffeurSection(context, loc);
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: PremiumButton(
                    text: loc.continueText,
                    onTap: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        // print("form valid");
                      }
                    },
                    fontsize: 16,
                    showLoader: false,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildArrivalSection(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildAirportName(context, loc),
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumDropDown(
            title: loc.terminal,
            value: _getTerminals(context)[_selectedTerminalCode],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedTerminalCode = _getTerminals(context).indexOf(val);
                });
              }
            },
            items: _getTerminals(context),
          ),
        ),
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumTextField(
            titleFontWeight: FontWeight.normal,
            fontsize: 14,
            title: loc.flightNumber,
            controller: flightNumberController,
            hintText: loc.enterFlightNumber,
            needBorder: true,
            blackbg: true,
            needAutoCapitalize: true,
            borderRadius: 8,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return loc.flightNumberIsRequired;
              }
              return null;
            },
          ),
        ),
        SizedBox(height: 16),
        buildDateTimePickers(context, loc, false),
        SizedBox(height: 16),
        buildDropLocation(context, loc, true),
      ],
    );
  }

  Widget buildDepartureSection(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildDropLocation(context, loc, false),
        SizedBox(height: 16),
        buildAirportName(context, loc),
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumDropDown(
            title: loc.terminal,
            value: _getTerminals(context)[_selectedTerminalCode],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedTerminalCode = _getTerminals(context).indexOf(val);
                });
              }
            },
            items: _getTerminals(context),
          ),
        ),
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: PremiumTextField(
            titleFontWeight: FontWeight.normal,
            fontsize: 14,
            title: loc.flightNumber,
            controller: flightNumberController,
            hintText: loc.enterFlightNumber,
            needBorder: true,
            blackbg: true,
            needAutoCapitalize: true,
            borderRadius: 8,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return loc.flightNumberIsRequired;
              }
              return null;
            },
          ),
        ),
        SizedBox(height: 16),
        buildDateTimePickers(context, loc, false),
        SizedBox(height: 16),
        buildDateTimePickers(context, loc, true),
      ],
    );
  }

  Widget buildChauffeurSection(BuildContext context, AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildDropLocation(context, loc, false),
        SizedBox(height: 16),
        buildDateTimePickers(context, loc, true),
        SizedBox(height: 16),
        buildDropLocation(context, loc, true),
      ],
    );
  }

  Widget buildDropLocation(
    BuildContext context,
    AppLocalizations loc,
    bool isDropLocation,
  ) {
    return FormField<bool>(
      validator: (value) {
        if (isDropLocation) {
          if (_dropLat == null || _dropLng == null) {
            return loc.dropLocationIsRequired;
          }
        } else {
          if (_pickupLat == null || _pickupLng == null) {
            return loc.pickupLocationIsRequired;
          }
        }
        return null;
      },
      builder: (state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            spacing: 8,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDropLocation ? loc.dropLocation : loc.pickupLocation,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              GestureDetector(
                onTap: () async {
                  double initLat = 24.7136; // Riyadh
                  double initLng = 46.6753; // Riyadh
                  if (_selectedCityCode == 1) {
                    // Dammam
                    initLat = 26.3927;
                    initLng = 49.9777;
                  } else if (_selectedCityCode == 2) {
                    // Jeddah
                    initLat = 21.4858;
                    initLng = 39.1925;
                  }

                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LocationPickerPage(
                        initialLat: initLat,
                        initialLng: initLng,
                        needCurrentLocationButton: false,
                      ),
                    ),
                  );
                  if (result != null && result is Map<String, dynamic>) {
                    if (isDropLocation) {
                      setState(() {
                        _dropAddress = result['address'];
                        _dropLat = result['lat'];
                        _dropLng = result['lng'];
                      });
                    } else {
                      setState(() {
                        _pickupAddress = result['address'];
                        _pickupLat = result['lat'];
                        _pickupLng = result['lng'];
                      });
                    }
                    state.didChange(true);
                  }
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: 60),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: state.hasError
                            ? const Color(0xFFCF6679)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            isDropLocation
                                ? _dropAddress ?? loc.tapToSelectADropLocation
                                : _pickupAddress ??
                                      loc.tapToSelectAPickupLocation,
                            style: TextStyle(
                              color: isDropLocation
                                  ? _dropAddress != null
                                        ? Colors.white
                                        : Colors.white60
                                  : _pickupAddress != null
                                  ? Colors.white
                                  : Colors.white60,
                              fontSize: 14,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 20),
                        Icon(
                          Icons.location_on_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    state.errorText!,
                    style: const TextStyle(
                      color: Color(0xFFCF6679),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget buildAirportName(BuildContext context, AppLocalizations loc) {
    String airportName = "King Khalid International Airport";
    if (_selectedCityCode == 1) {
      airportName = "King Fahd International Airport";
    } else if (_selectedCityCode == 2) {
      airportName = "King Abdulaziz International Airport";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        spacing: 5,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.airport,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      airportName,
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
    );
  }

  Widget buildDateTimePickers(
    BuildContext context,
    AppLocalizations loc,
    bool isPickup,
  ) {
    return FormField<bool>(
      validator: (value) {
        if (isPickup) {
          if (_selectedPickupDate == null || _selectedPickupTime == null) {
            return loc.pickupDateAndTimeIsRequired;
          }
        } else {
          if (_selectedDate == null || _selectedTime == null) {
            return loc.dateAndTimeIsRequired;
          }
        }
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                isPickup
                    ? loc.pickupDateAndTime
                    : _selectedCatCode == 0
                    ? loc.arrivalDateAndTime
                    : _selectedCatCode == 1
                    ? loc.departureDateAndTime
                    : loc.pickupDateAndTime,
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            SizedBox(height: 8),

            Container(
              height: 60,
              margin: EdgeInsets.symmetric(horizontal: 24),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: state.hasError
                      ? const Color(0xFFCF6679)
                      : Colors.white24,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate:
                              (isPickup
                                  ? _selectedPickupDate
                                  : _selectedDate) ??
                              DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                          confirmText: loc.done,
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: Color(0xffE4A46B),
                                  onPrimary: Colors.black,
                                  surface: Colors.grey.shade900,
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            if (isPickup) {
                              _selectedPickupDate = picked;
                            } else {
                              _selectedDate = picked;
                            }
                            if (isPickup) {
                              if (_selectedPickupTime != null) {
                                final now = DateTime.now();
                                if (picked.year == now.year &&
                                    picked.month == now.month &&
                                    picked.day == now.day) {
                                  if (_selectedPickupTime!.hour < now.hour ||
                                      (_selectedPickupTime!.hour == now.hour &&
                                          _selectedPickupTime!.minute <
                                              now.minute)) {
                                    _selectedPickupTime = null;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          loc.previouslySelectedTimeClearedAsItIsInThePast,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            } else {
                              if (_selectedTime != null) {
                                final now = DateTime.now();
                                if (picked.year == now.year &&
                                    picked.month == now.month &&
                                    picked.day == now.day) {
                                  if (_selectedTime!.hour < now.hour ||
                                      (_selectedTime!.hour == now.hour &&
                                          _selectedTime!.minute < now.minute)) {
                                    _selectedTime = null;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          loc.previouslySelectedTimeClearedAsItIsInThePast,
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            }
                          });
                          state.didChange(true);
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPickup
                              ? (_selectedPickupDate == null
                                    ? loc.selectDate
                                    : DateFormat(
                                        'dd MMM yyyy',
                                      ).format(_selectedPickupDate!))
                              : (_selectedDate == null
                                    ? loc.selectDate
                                    : DateFormat(
                                        'dd MMM yyyy',
                                      ).format(_selectedDate!)),
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        if (isPickup
                            ? _selectedPickupDate == null
                            : _selectedDate == null) {
                          OverlayEntry? overlayEntry;
                          overlayEntry = OverlayEntry(
                            builder: (context) => Positioned(
                              bottom:
                                  MediaQuery.of(context).viewInsets.bottom + 20,
                              left: 20,
                              right: 20,

                              child: Material(
                                color: Colors.transparent,
                                child: AnimatedSnackBar(
                                  type: "E",
                                  message: loc.pleaseSelectADateFirst,
                                  onDismissed: () {
                                    overlayEntry?.remove();
                                  },
                                ),
                              ),
                            ),
                          );
                          Overlay.of(context).insert(overlayEntry);
                          return;
                        }
                        showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            TimeOfDay tempTime =
                                (isPickup
                                    ? _selectedPickupTime
                                    : _selectedTime) ??
                                TimeOfDay.now();
                            String? errorMessage;
                            return StatefulBuilder(
                              builder: (context, setDialogState) {
                                return Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: ColorScheme.dark(
                                      surface: Colors.grey.shade900,
                                    ),
                                  ),
                                  child: AlertDialog(
                                    backgroundColor: Colors.grey.shade800,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    title: Text(
                                      loc.selectTime,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    content: SizedBox(
                                      height: 250,
                                      child: Column(
                                        children: [
                                          if (errorMessage != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 16.0,
                                                left: 16,
                                                right: 16,
                                              ),
                                              child: Text(
                                                errorMessage!,
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                  fontSize: 13,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          Expanded(
                                            child: CupertinoTheme(
                                              data: CupertinoThemeData(
                                                brightness: Brightness.dark,
                                                textTheme:
                                                    CupertinoTextThemeData(
                                                      dateTimePickerTextStyle:
                                                          TextStyle(
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                              ),
                                              child: CupertinoDatePicker(
                                                mode: CupertinoDatePickerMode
                                                    .time,
                                                use24hFormat: false,
                                                initialDateTime: DateTime(
                                                  DateTime.now().year,
                                                  DateTime.now().month,
                                                  DateTime.now().day,
                                                  tempTime.hour,
                                                  tempTime.minute,
                                                ),
                                                onDateTimeChanged:
                                                    (DateTime newDateTime) {
                                                      setDialogState(() {
                                                        errorMessage = null;
                                                        tempTime =
                                                            TimeOfDay.fromDateTime(
                                                              newDateTime,
                                                            );
                                                      });
                                                    },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          bool isToday = false;
                                          final now = DateTime.now();
                                          DateTime? dateToCheck = isPickup
                                              ? _selectedPickupDate
                                              : _selectedDate;
                                          if (dateToCheck != null) {
                                            if (dateToCheck.year == now.year &&
                                                dateToCheck.month ==
                                                    now.month &&
                                                dateToCheck.day == now.day) {
                                              isToday = true;
                                            }
                                          } else {
                                            isToday = true;
                                          }
                                          if (isToday) {
                                            if (tempTime.hour < now.hour ||
                                                (tempTime.hour == now.hour &&
                                                    tempTime.minute <
                                                        now.minute)) {
                                              setDialogState(() {
                                                errorMessage =
                                                loc.cannotSelectPastTimeForToday;
                                              });
                                              return;
                                            }
                                          }
                                          setState(() {
                                            if (isPickup) {
                                              _selectedPickupTime = tempTime;
                                            } else {
                                              _selectedTime = tempTime;
                                            }
                                          });
                                          state.didChange(true);
                                          Navigator.of(dialogContext).pop();
                                        },
                                        child: Text(
                                          loc.done,
                                          style: TextStyle(
                                            color: Color(0xffE4A46B),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isPickup
                              ? (_selectedPickupTime == null
                                    ? loc.selectTime
                                    : _selectedPickupTime!.format(context))
                              : (_selectedTime == null
                                    ? loc.selectTime
                                    : _selectedTime!.format(context)),
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 4),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(
                    color: Color(0xFFCF6679),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
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
