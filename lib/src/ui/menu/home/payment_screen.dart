import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:ketamiz/src/model/api/book_model.dart';
import 'package:ketamiz/src/model/passenger_model.dart';
import 'package:ketamiz/src/services/feature_flags.dart';
import 'package:ketamiz/src/ui/dialogs/center_dialog.dart';
import 'package:ketamiz/src/ui/menu/main_screen.dart';
import 'package:ketamiz/src/ui/menu/profile/top_up_screen.dart';
import 'package:ketamiz/src/ui/widgets/buttons/primary_button.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../lan_localization/load_places.dart';
import '../../../model/api/trip_list_model.dart';
import '../../../model/location_model.dart';
import '../../../resources/repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/utils.dart';
import '../../dialogs/snack_bar.dart';
import '../../widgets/containers/leading_back.dart';
import '../../widgets/texts/text_16h_500w.dart';
import 'map_route_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.trip,
    this.passengersNum = 1,
    required this.passengers,
  });

  final TripListModel trip;
  final int passengersNum;
  final List<PassengerModel> passengers;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const int _paymentTimeoutSeconds = 720;

  String weekDay = '';
  String month = '';
  String t1 = '';
  String m1 = '';
  String h1 = '';
  String seconds = "00";
  int _remainingSeconds = _paymentTimeoutSeconds;
  Timer? _countdownTimer;
  String pricePerSeat = "";
  String balance = "";

  String fromRegion = "";
  String fromCity = "";
  String fromNeighborhood = "";
  String toRegion = "";
  String toCity = "";
  String toNeighborhood = "";
  String from = "";
  String to = "";

  bool isLoading = false;

  final Repository _repository = Repository();

  @override
  void initState() {
    super.initState();
    if (widget.trip.pricePerSeat.contains(".")) {
      pricePerSeat = widget.trip.pricePerSeat.split(".")[0];
    } else {
      pricePerSeat = widget.trip.pricePerSeat;
    }
    _startTimer();
    initTimeState(widget.trip.startTime);
    getBalance();
    setLocations();
  }

  static final _unknownLocation =
      LocationModel(id: "0", text: "", parentID: "0");

  /// API trips carry location *names* (start_region etc.); ID lookups are
  /// only a fallback — IDs are often absent, which used to render "—".
  Future<void> setLocations() async {
    final trip = widget.trip;

    if (trip.fromRegion.isNotEmpty ||
        trip.fromCity.isNotEmpty ||
        trip.fromVillage.isNotEmpty) {
      fromRegion = trip.fromRegion;
      fromCity = trip.fromCity;
      fromNeighborhood = trip.fromVillage;
      toRegion = trip.toRegion;
      toCity = trip.toCity;
      toNeighborhood = trip.toVillage;
    } else {
      if (LocationData.regions.isEmpty) {
        await LocationData.loadPlaces(context);
      }
      fromRegion = LocationData.regions
          .firstWhere((r) => r.id == trip.fromRegionId.toString(),
              orElse: () => _unknownLocation)
          .text;
      fromCity = LocationData.cities
          .firstWhere((c) => c.id == trip.fromCityId.toString(),
              orElse: () => _unknownLocation)
          .text;
      fromNeighborhood = LocationData.villages
          .firstWhere((n) => n.id == trip.fromVillageId.toString(),
              orElse: () => _unknownLocation)
          .text;
      toRegion = LocationData.regions
          .firstWhere((r) => r.id == trip.toRegionId.toString(),
              orElse: () => _unknownLocation)
          .text;
      toCity = LocationData.cities
          .firstWhere((c) => c.id == trip.toCityId.toString(),
              orElse: () => _unknownLocation)
          .text;
      toNeighborhood = LocationData.villages
          .firstWhere((n) => n.id == trip.toVillageId.toString(),
              orElse: () => _unknownLocation)
          .text;
    }

    if (!mounted) return;
    setState(() {
      from = [fromNeighborhood, fromCity, fromRegion]
          .where((s) => s.isNotEmpty)
          .join(", ");
      to = [toNeighborhood, toCity, toRegion]
          .where((s) => s.isNotEmpty)
          .join(", ");
    });
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
            seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  int get _totalPrice =>
      (int.tryParse(pricePerSeat) ?? 0) * widget.passengersNum;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: const LeadingBack(),
        title: Text16h500w(title: translate("home.payment_details")),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
            children: [
              _buildCountdownCard(),
              const SizedBox(height: 14),
              _buildTripCard(),
              const SizedBox(height: 14),
              _buildInfoBanner(),
              const SizedBox(height: 14),
              _buildBalanceCard(),
              const SizedBox(height: 20),
              _sectionLabel(translate("home.payment")),
              const SizedBox(height: 10),
              _buildBreakdownCard(),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _onConfirmPayment,
                    child: PrimaryButton(
                      title: translate("home.confirm_payment"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTermsFooter(),
                ],
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: AppTheme.black.withOpacity(0.45),
              child: Center(
                child: Container(
                  height: 96,
                  width: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.purple),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Cards ─────────────────────────────────────────────────────────────────

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 20,
            color: AppTheme.black.withOpacity(0.04),
          ),
        ],
      );

  Widget _iconBox(IconData icon, {Color color = AppTheme.purple}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  Widget _buildCountdownCard() {
    final mins = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final danger = _remainingSeconds < 30;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _iconBox(Icons.calendar_today_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              translate("home.complete_payment_within"),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
                color: AppTheme.black,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _timerUnit(mins, translate("home.minutes_short"), danger),
          SizedBox(
            height: 40,
            child: Center(
              child: Text(
                ":",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: danger ? AppTheme.red : AppTheme.purple,
                ),
              ),
            ),
          ),
          _timerUnit(seconds, translate("home.seconds_short"), danger),
        ],
      ),
    );
  }

  Widget _timerUnit(String value, String label, bool danger) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: danger ? AppTheme.red : AppTheme.purple,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: AppTheme.gray,
          ),
        ),
      ],
    );
  }

  Widget _buildTripCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 16, color: AppTheme.gray),
              const SizedBox(width: 8),
              Text(
                "$h1:$m1 $t1",
                style: const TextStyle(
                  color: AppTheme.black,
                  fontSize: 14,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.gray,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text(
                  "$weekDay, $month ${widget.trip.startTime.day}",
                  style: const TextStyle(
                    color: AppTheme.gray,
                    fontSize: 14,
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _routeRow(
            leading: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: AppTheme.purple, width: 3),
              ),
            ),
            text: from.isEmpty ? "—" : from,
          ),
          Container(
            height: 16,
            margin: const EdgeInsets.only(left: 7),
            width: 2,
            color: AppTheme.border,
          ),
          _routeRow(
            leading: const Icon(Icons.location_on_rounded,
                color: AppTheme.red, size: 18),
            text: to.isEmpty ? "—" : to,
          ),
          if (widget.trip.vehicle.model.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppTheme.border),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.directions_car_rounded,
                    color: AppTheme.purple, size: 18),
                const SizedBox(width: 10),
                Text(
                  widget.trip.vehicle.model.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.black,
                    fontSize: 13,
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                if (widget.trip.vehicle.seats > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.light,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${widget.trip.vehicle.seats} ${translate("history.seats")}",
                      style: const TextStyle(
                        color: AppTheme.gray,
                        fontSize: 11,
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _routeRow({required Widget leading, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 16,
          child: Center(child: leading),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.black,
                fontSize: 14,
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _openRoute,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.purple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.near_me_rounded,
                size: 15, color: AppTheme.purple),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBanner() {
    return GestureDetector(
      onTap: () => CenterDialog.showInfo(
        context,
        translate("home.payment_details"),
        translate("home.payment_info"),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.blue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppTheme.blue, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                translate("home.payment_info"),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: AppTheme.blue,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.blue, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _iconBox(Icons.account_balance_wallet_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate("profile.my_balance"),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.gray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${Utils.priceFormat(balance)} ${translate("currency")}",
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TopUpScreen()),
              ).then((_) => getBalance());
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: AppTheme.purple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    translate("profile.top_up"),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.add_circle_outline_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _payRow(
            icon: Icons.person_outline_rounded,
            label: translate("home.number_passenger"),
            value: "${widget.passengersNum}",
          ),
          const SizedBox(height: 14),
          _payRow(
            icon: Icons.sell_outlined,
            label: translate("home.price_per_seat"),
            value:
                "${Utils.priceFormat(pricePerSeat)} ${translate("currency")}",
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 14),
          _payRow(
            label: translate("home.total_price"),
            value:
                "${Utils.priceFormat(_totalPrice.toString())} ${translate("currency")}",
            bold: true,
            valueColor: AppTheme.purple,
          ),
        ],
      ),
    );
  }

  Widget _payRow({
    IconData? icon,
    required String label,
    required String value,
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: AppTheme.gray),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: bold ? AppTheme.black : AppTheme.gray,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? AppTheme.black,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.black,
        ),
      ),
    );
  }

  Widget _buildTermsFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 13, color: AppTheme.gray),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            translate("home.payment_terms"),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w400,
              height: 1.3,
              color: AppTheme.gray,
            ),
          ),
        ),
      ],
    );
  }

  void _openRoute() {
    final s = LatLng(double.tryParse(widget.trip.startLat) ?? 0,
        double.tryParse(widget.trip.startLong) ?? 0);
    final e = LatLng(double.tryParse(widget.trip.endLat) ?? 0,
        double.tryParse(widget.trip.endLong) ?? 0);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapRouteScreen(
          start: s,
          end: e,
          startText: from,
          endText: to,
          // Not booked yet — exact points only while the flag reveals them.
          approximate: !FeatureFlags.revealTripDetails,
        ),
      ),
    );
  }

  Future<void> _onConfirmPayment() async {
    if (_remainingSeconds <= 0) {
      CenterDialog.showActionFailed(
        context,
        translate("ketamiz.time_is_up"),
        translate("ketamiz.time_is_up_msg"),
      );
      return;
    }
    if (Utils().stringToInt(balance) <= _totalPrice) {
      CenterDialog.showActionFailed(
        context,
        translate("ketamiz.not_enough_balance"),
        translate("ketamiz.not_enough_balance_msg"),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      var response = await _repository.fetchBookTrip(
          widget.trip.id.toString(), widget.passengers);
      if (!mounted) return;

      if (response.isSuccess) {
        var result = BookModel.fromJson(response.result);
        if (result.status == "confirmed") {
          CustomSnackBar().showSnackBar(
            context,
            translate("ketamiz.booking_success"),
            1,
          );
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setString("active_booked_id", result.bookingId.toString());
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        } else {
          CenterDialog.showActionFailed(
            context,
            translate("ketamiz.booking_failed"),
            translate("ketamiz.booking_failed_msg"),
          );
        }
      } else {
        if (response.status == -1) {
          CenterDialog.showActionFailed(
            context,
            translate("auth.connection_failed"),
            translate("auth.connection_failed_msg"),
          );
        } else {
          CenterDialog.showActionFailed(
            context,
            translate("auth.something_went_wrong"),
            translate("auth.failed_msg"),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      CenterDialog.showActionFailed(
        context,
        translate("auth.something_went_wrong"),
        translate("auth.failed_msg"),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void initTimeState(DateTime time) {
    m1 = time.minute < 10 ? '0${time.minute}' : time.minute.toString();
    time.weekday == 1
        ? weekDay = 'Monday'
        : time.weekday == 2
            ? weekDay = 'Tuesday'
            : time.weekday == 3
                ? weekDay = 'Wednesday'
                : time.weekday == 4
                    ? weekDay = 'Thursday'
                    : time.weekday == 5
                        ? weekDay = 'Friday'
                        : time.weekday == 6
                            ? weekDay = 'Saturday'
                            : weekDay = 'Sunday';

    time.month == 1
        ? month = 'January'
        : time.month == 2
            ? month = 'February'
            : time.month == 3
                ? month = 'March'
                : time.month == 4
                    ? month = 'April'
                    : time.month == 5
                        ? month = 'May'
                        : time.month == 6
                            ? month = 'June'
                            : time.month == 7
                                ? month = 'July'
                                : time.month == 8
                                    ? month = 'August'
                                    : time.month == 9
                                        ? month = 'September'
                                        : time.month == 10
                                            ? month = 'October'
                                            : time.month == 11
                                                ? month = 'November'
                                                : month = 'December';

    time.hour < 12 ? t1 = 'AM' : t1 = 'PM';
    h1 = time.hour == 0
        ? '12'
        : (time.hour > 12 ? (time.hour - 12).toString() : time.hour.toString());
  }

  Future<void> getBalance() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        balance = prefs.getString('balance') ?? "0";
      });
    }
  }
}
