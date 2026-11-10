import 'package:flutter_test/flutter_test.dart';
import 'package:geoxal/core/services/charge_calculator.dart';
import 'package:geoxal/data/models/charge.dart';

void main() {
  group('ChargeCalculator - Simple Charges Tests', () {
    test('Water invoice: 15,000 DZD for 30 days (01/09/2026 to 30/09/2026)', () {
      final charge = Charge(
        id: 'c1',
        userId: 'u1',
        dateCreation: DateTime(2026, 9, 1),
        referance: 'CHG-001',
        dateCharge: DateTime(2026, 9, 1),
        compteId: 'compte-eau',
        categorie: CategorieCharge.simple,
        amortissable: false,
        dateDebutConsommation: DateTime(2026, 9, 1),
        dateFinConsommation: DateTime(2026, 9, 30),
        montantCharge: 15000.0,
        designation: 'Facture Eau',
      );

      // Full period: 01/09/2026 to 30/09/2026 (30 days)
      final fullReport = ChargeCalculator.calculateSimpleCharge(
        charge: charge,
        reportStart: DateTime(2026, 9, 1),
        reportEnd: DateTime(2026, 9, 30),
      );
      expect(fullReport.totalConsumptionDays, 30);
      expect(fullReport.overlappingDays, 30);
      expect(fullReport.periodAmount, 15000.0);

      // Partial period: 01/09/2026 to 07/09/2026 (7 days -> 500 DZD/day * 7 = 3,500 DZD)
      final partialReport = ChargeCalculator.calculateSimpleCharge(
        charge: charge,
        reportStart: DateTime(2026, 9, 1),
        reportEnd: DateTime(2026, 9, 7),
      );
      expect(partialReport.overlappingDays, 7);
      expect(partialReport.periodAmount, 3500.0);
    });

    test('Specification Example: 15,000 DZD over 122 days (01/09/2026 to 31/12/2026), report Sept only (30 days)', () {
      final charge = Charge(
        id: 'c2',
        userId: 'u1',
        dateCreation: DateTime(2026, 9, 1),
        referance: 'CHG-002',
        dateCharge: DateTime(2026, 9, 1),
        compteId: 'compte-test',
        categorie: CategorieCharge.simple,
        amortissable: false,
        dateDebutConsommation: DateTime(2026, 9, 1),
        dateFinConsommation: DateTime(2026, 12, 31),
        montantCharge: 15000.0,
        designation: 'Contrat Maintenance',
      );

      final report = ChargeCalculator.calculateSimpleCharge(
        charge: charge,
        reportStart: DateTime(2026, 9, 1),
        reportEnd: DateTime(2026, 9, 30),
      );
      expect(report.totalConsumptionDays, 122);
      expect(report.overlappingDays, 30);
      // 15,000 * 30 / 122 = 3688.5245... -> 3688.52 DZD
      expect(report.periodAmount, 3688.52);
    });

    test('No overlap returns 0', () {
      final charge = Charge(
        id: 'c3',
        userId: 'u1',
        dateCreation: DateTime(2026, 9, 1),
        referance: 'CHG-003',
        dateCharge: DateTime(2026, 9, 1),
        compteId: 'compte-test',
        categorie: CategorieCharge.simple,
        amortissable: false,
        dateDebutConsommation: DateTime(2026, 9, 1),
        dateFinConsommation: DateTime(2026, 9, 30),
        montantCharge: 15000.0,
        designation: 'Eau',
      );

      final report = ChargeCalculator.calculateSimpleCharge(
        charge: charge,
        reportStart: DateTime(2026, 10, 1),
        reportEnd: DateTime(2026, 10, 31),
      );
      expect(report.overlappingDays, 0);
      expect(report.periodAmount, 0.0);
    });
  });

  group('ChargeCalculator - Amortizable Charges Tests', () {
    test('Computer asset: 40,000 DZD amortized from 01/09/2026 to 31/12/2026', () {
      final charge = Charge(
        id: 'a1',
        userId: 'u1',
        dateCreation: DateTime(2026, 9, 1),
        referance: 'CHG-AM-001',
        dateCharge: DateTime(2026, 9, 1),
        compteId: 'compte-materiel',
        categorie: CategorieCharge.amortisable,
        amortissable: true,
        dateDebutAmortissement: DateTime(2026, 9, 1),
        dateFinAmortissement: DateTime(2026, 12, 31),
        montantCharge: 40000.0,
        designation: 'Ordinateur portable',
      );

      // Report for September (30 days out of 122)
      final septReport = ChargeCalculator.calculateAmortizableCharge(
        charge: charge,
        reportStart: DateTime(2026, 9, 1),
        reportEnd: DateTime(2026, 9, 30),
      );

      expect(septReport.totalAmortizationDays, 122);
      expect(septReport.periodOverlappingDays, 30);
      expect(septReport.elapsedDaysToReportEnd, 30);
      // 40000 * 30 / 122 = 9836.0655... -> 9836.07
      expect(septReport.periodAmortization, 9836.07);
      expect(septReport.cumulativeAmortization, 9836.07);
      expect(septReport.remainingAmortization, 40000.0 - 9836.07);

      // Report for October (31 days out of 122)
      final octReport = ChargeCalculator.calculateAmortizableCharge(
        charge: charge,
        reportStart: DateTime(2026, 10, 1),
        reportEnd: DateTime(2026, 10, 31),
      );
      // Period is 31 days (Oct)
      // Cumulative up to 31/10 is 30 (Sep) + 31 (Oct) = 61 days
      expect(octReport.periodOverlappingDays, 31);
      expect(octReport.elapsedDaysToReportEnd, 61);
      // 40000 * 31 / 122 = 10163.93
      expect(octReport.periodAmortization, 10163.93);
      // 40000 * 61 / 122 = 20000.00
      expect(octReport.cumulativeAmortization, 20000.00);
      expect(octReport.remainingAmortization, 20000.00);
    });
  });
}

