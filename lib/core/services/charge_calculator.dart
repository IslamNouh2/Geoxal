import '../../data/models/charge.dart';

/// Result of calculation for a single Charge Simple over an inquiry period.
class SimpleChargePeriodReportItem {
  final Charge charge;
  final DateTime consumptionStart;
  final DateTime consumptionEnd;
  final int totalConsumptionDays;
  final int overlappingDays;
  final double originalAmount;
  final double periodAmount;

  const SimpleChargePeriodReportItem({
    required this.charge,
    required this.consumptionStart,
    required this.consumptionEnd,
    required this.totalConsumptionDays,
    required this.overlappingDays,
    required this.originalAmount,
    required this.periodAmount,
  });

  // Backward compatibility aliases
  int get joursConsommation => totalConsumptionDays;
  int get joursPeriode => overlappingDays;
  double get montantPeriode => periodAmount;
}

// Backward compatibility alias for type name
typedef SimpleChargeCalculation = SimpleChargePeriodReportItem;

/// Result of calculation for a single Charge Amortissable over an inquiry period.
class AmortizableChargeReportItem {
  final Charge charge;
  final DateTime amortStart;
  final DateTime amortEnd;
  final int totalAmortizationDays;
  final int periodOverlappingDays;
  final int elapsedDaysToReportEnd;
  final double originalAmount;
  final double periodAmortization;
  final double cumulativeAmortization;
  final double remainingAmortization;

  const AmortizableChargeReportItem({
    required this.charge,
    required this.amortStart,
    required this.amortEnd,
    required this.totalAmortizationDays,
    required this.periodOverlappingDays,
    required this.elapsedDaysToReportEnd,
    required this.originalAmount,
    required this.periodAmortization,
    required this.cumulativeAmortization,
    required this.remainingAmortization,
  });

  // Backward compatibility aliases
  int get joursAmortissementTotal => totalAmortizationDays;
  int get joursPeriode => periodOverlappingDays;
  double get montantAmortiPeriode => periodAmortization;
  double get montantAmortiCumule => cumulativeAmortization;
  double get resteAAmortir => remainingAmortization;
}

// Backward compatibility alias for type name
typedef AmortizableChargeCalculation = AmortizableChargeReportItem;


/// Accounting and period calculation service for Charges (Simples & Amortissables).
///
/// Ensures:
/// - Inclusive date counts (both start and end dates counted).
/// - Exact leap-year and February handling.
/// - Decimal rounding to 2 decimals with exact matching when report period covers 100% of consumption/amortization.
class ChargeCalculator {
  /// Strip time component so calculations are purely calendar date based.
  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Inclusive count of days between two dates [start, end].
  /// If start == end, returns 1 day.
  /// If end < start, returns 0.
  static int inclusiveDays(DateTime start, DateTime end) {
    final s = dateOnly(start);
    final e = dateOnly(end);
    if (e.isBefore(s)) return 0;
    return e.difference(s).inDays + 1;
  }

  /// Calculates the overlap in inclusive days between two periods:
  /// [startA, endA] and [startB, endB].
  static int overlapDays({
    required DateTime startA,
    required DateTime endA,
    required DateTime startB,
    required DateTime endB,
  }) {
    final sA = dateOnly(startA);
    final eA = dateOnly(endA);
    final sB = dateOnly(startB);
    final eB = dateOnly(endB);

    final maxStart = sA.isAfter(sB) ? sA : sB;
    final minEnd = eA.isBefore(eB) ? eA : eB;

    if (minEnd.isBefore(maxStart)) return 0;
    return minEnd.difference(maxStart).inDays + 1;
  }

  /// Calculates the attributable period amount for a Charge Simple.
  ///
  /// Formula:
  /// Period Amount = Total Amount * (Overlapping Days / Total Consumption Days)
  ///
  /// If report covers entire consumption period, returns exactly originalAmount.
  static SimpleChargePeriodReportItem calculateSimpleCharge({
    required Charge charge,
    required DateTime reportStart,
    required DateTime reportEnd,
  }) {
    final consStart = dateOnly(charge.dateDebutConsommation ?? charge.dateCharge);
    final consEnd = dateOnly(charge.dateFinConsommation ?? consStart);

    final totalDays = inclusiveDays(consStart, consEnd);
    final overlap = overlapDays(
      startA: consStart,
      endA: consEnd,
      startB: reportStart,
      endB: reportEnd,
    );

    double periodAmount = 0.0;
    if (totalDays > 0 && overlap > 0) {
      if (overlap >= totalDays) {
        // Covers 100% of consumption: avoid rounding differences
        periodAmount = charge.montantCharge;
      } else {
        final rawAmount = (charge.montantCharge * overlap) / totalDays;
        periodAmount = (rawAmount * 100).round() / 100.0;
      }
    }

    return SimpleChargePeriodReportItem(
      charge: charge,
      consumptionStart: consStart,
      consumptionEnd: consEnd,
      totalConsumptionDays: totalDays,
      overlappingDays: overlap,
      originalAmount: charge.montantCharge,
      periodAmount: periodAmount,
    );
  }

  /// Calculates the amortization figures for a Charge Amortissable for a report period.
  ///
  /// Formulas:
  /// Total Days = inclusiveDays(amortStart, amortEnd)
  /// Period Amortization = Total Amount * (Period Overlapping Days / Total Days)
  /// Cumulative Amortization = Total Amount * (Elapsed Days up to reportEnd / Total Days)
  /// Remaining Amortization = Total Amount - Cumulative Amortization
  static AmortizableChargeReportItem calculateAmortizableCharge({
    required Charge charge,
    required DateTime reportStart,
    required DateTime reportEnd,
  }) {
    // Amortization start is charge creation date
    final amortStart = dateOnly(charge.dateDebutAmortissement ?? charge.dateCreation);
    final amortEnd = dateOnly(charge.dateFinAmortissement ?? amortStart);

    final totalDays = inclusiveDays(amortStart, amortEnd);
    final periodOverlap = overlapDays(
      startA: amortStart,
      endA: amortEnd,
      startB: reportStart,
      endB: reportEnd,
    );

    // Cumulative: overlap between amortStart and reportEnd
    final rEnd = dateOnly(reportEnd);
    int elapsedDays = 0;
    if (!rEnd.isBefore(amortStart)) {
      final effectiveCumulativeEnd = rEnd.isBefore(amortEnd) ? rEnd : amortEnd;
      elapsedDays = inclusiveDays(amortStart, effectiveCumulativeEnd);
    }

    double periodAmort = 0.0;
    double cumulativeAmort = 0.0;

    if (totalDays > 0) {
      if (periodOverlap >= totalDays) {
        periodAmort = charge.montantCharge;
      } else if (periodOverlap > 0) {
        final rawPeriod = (charge.montantCharge * periodOverlap) / totalDays;
        periodAmort = (rawPeriod * 100).round() / 100.0;
      }

      if (elapsedDays >= totalDays) {
        cumulativeAmort = charge.montantCharge;
      } else if (elapsedDays > 0) {
        final rawCumulative = (charge.montantCharge * elapsedDays) / totalDays;
        cumulativeAmort = (rawCumulative * 100).round() / 100.0;
      }
    }

    double remaining = charge.montantCharge - cumulativeAmort;
    if (remaining < 0.001) remaining = 0.0;
    remaining = (remaining * 100).round() / 100.0;

    return AmortizableChargeReportItem(
      charge: charge,
      amortStart: amortStart,
      amortEnd: amortEnd,
      totalAmortizationDays: totalDays,
      periodOverlappingDays: periodOverlap,
      elapsedDaysToReportEnd: elapsedDays,
      originalAmount: charge.montantCharge,
      periodAmortization: periodAmort,
      cumulativeAmortization: cumulativeAmort,
      remainingAmortization: remaining,
    );
  }
}
