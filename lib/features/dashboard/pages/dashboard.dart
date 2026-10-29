import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(),
          const SizedBox(height: 28),

          _buildStats(),
          const SizedBox(height: 24),

          _buildAnalyticsSection(),
          const SizedBox(height: 24),

          _buildBottomSection(),
          const SizedBox(height: 24),

          _buildQuickActions(),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildWelcomeHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Good morning, Administrator 👋',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepSpaceBlue,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Here's what's happening with your business today.",
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.deepSpaceBlue.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),

        // Date
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: AppColors.coolSteel.withOpacity(0.35),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 17,
                color: AppColors.steelBlue,
              ),
              const SizedBox(width: 9),
              Text(
                _currentDate(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.deepSpaceBlue,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _currentDate() {
    final now = DateTime.now();

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  // ============================================================
  // STAT CARDS
  // ============================================================

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            title: 'Total Revenue',
            value: '2,580,000 DA',
            change: '+12.5%',
            subtitle: 'vs last month',
            icon: Icons.payments_outlined,
            iconColor: AppColors.steelBlue,
            positive: true,
          ),
        ),
        const SizedBox(width: 16),

        Expanded(
          child: _statCard(
            title: 'Total Sales',
            value: '128',
            change: '+8.2%',
            subtitle: 'vs last month',
            icon: Icons.point_of_sale_outlined,
            iconColor: AppColors.deepSpaceBlue,
            positive: true,
          ),
        ),
        const SizedBox(width: 16),

        Expanded(
          child: _statCard(
            title: 'Customers',
            value: '1,284',
            change: '+5.4%',
            subtitle: 'vs last month',
            icon: Icons.people_outline_rounded,
            iconColor: AppColors.steelBlue,
            positive: true,
          ),
        ),
        const SizedBox(width: 16),

        Expanded(
          child: _statCard(
            title: 'Products',
            value: '356',
            change: '+2.1%',
            subtitle: 'vs last month',
            icon: Icons.inventory_2_outlined,
            iconColor: AppColors.amberFlame,
            positive: true,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String change,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool positive,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.coolSteel.withOpacity(0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: iconColor,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.more_horiz,
                color: AppColors.coolSteel,
                size: 20,
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.deepSpaceBlue.withOpacity(0.60),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.deepSpaceBlue,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Icon(
                positive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 16,
                color: positive
                    ? AppColors.steelBlue
                    : AppColors.brickEmber,
              ),
              const SizedBox(width: 4),
              Text(
                change,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: positive
                      ? AppColors.steelBlue
                      : AppColors.brickEmber,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.deepSpaceBlue.withOpacity(0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ANALYTICS
  // ============================================================

  Widget _buildAnalyticsSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildRevenueChart(),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildSalesSummary(),
        ),
      ],
    );
  }

  // ============================================================
  // REVENUE CHART
  // ============================================================

  Widget _buildRevenueChart() {
    return _panel(
      title: 'Revenue Overview',
      subtitle: 'Monthly revenue performance',
      child: SizedBox(
        height: 280,
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  '2,580,000 DA',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepSpaceBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.steelBlue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    '+12.5%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.steelBlue,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            Expanded(
              child: CustomPaint(
                painter: _RevenueChartPainter(),
                child: const SizedBox.expand(),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _ChartLabel('Jan'),
                _ChartLabel('Feb'),
                _ChartLabel('Mar'),
                _ChartLabel('Apr'),
                _ChartLabel('May'),
                _ChartLabel('Jun'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SALES SUMMARY
  // ============================================================

  Widget _buildSalesSummary() {
    return _panel(
      title: 'Sales Summary',
      subtitle: 'Sales by category',
      child: SizedBox(
        height: 280,
        child: Column(
          children: [
            const SizedBox(height: 15),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _bar(
                    label: 'Jan',
                    value: 0.55,
                    amount: '320K',
                  ),
                  _bar(
                    label: 'Feb',
                    value: 0.72,
                    amount: '420K',
                  ),
                  _bar(
                    label: 'Mar',
                    value: 0.62,
                    amount: '365K',
                  ),
                  _bar(
                    label: 'Apr',
                    value: 0.88,
                    amount: '510K',
                  ),
                  _bar(
                    label: 'May',
                    value: 0.76,
                    amount: '440K',
                  ),
                  _bar(
                    label: 'Jun',
                    value: 1.0,
                    amount: '580K',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.steelBlue,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Revenue',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.deepSpaceBlue.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar({
    required String label,
    required double value,
    required String amount,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          amount,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.deepSpaceBlue,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 24,
          height: 135 * value,
          decoration: BoxDecoration(
            color: AppColors.steelBlue,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(5),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.deepSpaceBlue.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTTOM SECTION
  // ============================================================

  Widget _buildBottomSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _buildRecentSales(),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildLowStock(),
        ),
      ],
    );
  }

  // ============================================================
  // RECENT SALES
  // ============================================================

  Widget _buildRecentSales() {
    return _panel(
      title: 'Recent Sales',
      subtitle: 'Latest transactions',
      action: 'View all',
      child: Column(
        children: [
          const SizedBox(height: 15),

          _saleRow(
            invoice: 'INV-1024',
            customer: 'ABC Distribution',
            date: 'Today, 10:32',
            amount: '125,000 DA',
            status: 'Paid',
          ),

          _saleRow(
            invoice: 'INV-1023',
            customer: 'XYZ Commerce',
            date: 'Today, 09:18',
            amount: '82,500 DA',
            status: 'Paid',
          ),

          _saleRow(
            invoice: 'INV-1022',
            customer: 'Client Premium',
            date: 'Yesterday',
            amount: '65,000 DA',
            status: 'Pending',
          ),

          _saleRow(
            invoice: 'INV-1021',
            customer: 'Algeria Trade',
            date: 'Yesterday',
            amount: '210,000 DA',
            status: 'Paid',
          ),
        ],
      ),
    );
  }

  Widget _saleRow({
    required String invoice,
    required String customer,
    required String date,
    required String amount,
    required String status,
  }) {
    final isPaid = status == 'Paid';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.coolSteel.withOpacity(0.18),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.deepSpaceBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 19,
              color: AppColors.deepSpaceBlue,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepSpaceBlue,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  customer,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.deepSpaceBlue.withOpacity(0.50),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Text(
              date,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.deepSpaceBlue.withOpacity(0.45),
              ),
            ),
          ),

          Text(
            amount,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.deepSpaceBlue,
            ),
          ),

          const SizedBox(width: 15),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: isPaid
                  ? AppColors.steelBlue.withOpacity(0.10)
                  : AppColors.amberFlame.withOpacity(0.15),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isPaid
                    ? AppColors.steelBlue
                    : const Color(0xFF9A6B00),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOW STOCK
  // ============================================================

  Widget _buildLowStock() {
    return _panel(
      title: 'Low Stock',
      subtitle: 'Products requiring attention',
      action: 'View stock',
      child: Column(
        children: [
          const SizedBox(height: 15),

          _stockRow(
            name: 'Product A',
            code: 'PRD-001',
            quantity: 4,
          ),

          _stockRow(
            name: 'Product B',
            code: 'PRD-018',
            quantity: 7,
          ),

          _stockRow(
            name: 'Product C',
            code: 'PRD-032',
            quantity: 2,
          ),

          _stockRow(
            name: 'Product D',
            code: 'PRD-045',
            quantity: 9,
          ),
        ],
      ),
    );
  }

  Widget _stockRow({
    required String name,
    required String code,
    required int quantity,
  }) {
    final critical = quantity <= 4;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.coolSteel.withOpacity(0.18),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: critical
                  ? AppColors.brickEmber.withOpacity(0.08)
                  : AppColors.amberFlame.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 19,
              color: critical
                  ? AppColors.brickEmber
                  : AppColors.amberFlame,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepSpaceBlue,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  code,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.deepSpaceBlue.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$quantity',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: critical
                      ? AppColors.brickEmber
                      : AppColors.deepSpaceBlue,
                ),
              ),
              Text(
                'units',
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.deepSpaceBlue.withOpacity(0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return _panel(
      title: 'Quick Actions',
      subtitle: 'Frequently used operations',
      child: Row(
        children: [
          Expanded(
            child: _quickAction(
              icon: Icons.person_add_alt_1_rounded,
              title: 'New Customer',
              color: AppColors.steelBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _quickAction(
              icon: Icons.add_box_outlined,
              title: 'New Product',
              color: AppColors.deepSpaceBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _quickAction(
              icon: Icons.point_of_sale_rounded,
              title: 'New Sale',
              color: AppColors.steelBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _quickAction(
              icon: Icons.shopping_cart_outlined,
              title: 'New Purchase',
              color: AppColors.amberFlame,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: color,
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepSpaceBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PANEL
  // ============================================================

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
    String? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.coolSteel.withOpacity(0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepSpaceBlue,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.deepSpaceBlue.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),

              if (action != null)
                TextButton(
                  onPressed: () {},
                  child: Text(
                    action,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.steelBlue,
                    ),
                  ),
                ),
            ],
          ),

          child,
        ],
      ),
    );
  }
}

// ============================================================
// CHART LABEL
// ============================================================

class _ChartLabel extends StatelessWidget {
  final String text;

  const _ChartLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: AppColors.deepSpaceBlue.withOpacity(0.45),
      ),
    );
  }
}

// ============================================================
// REVENUE CHART PAINTER
// ============================================================

class _RevenueChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.coolSteel.withOpacity(0.18)
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = AppColors.steelBlue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = AppColors.steelBlue.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    // Horizontal grid lines
    for (int i = 0; i < 4; i++) {
      final y = size.height * i / 3;

      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final points = [
      Offset(size.width * 0.02, size.height * 0.78),
      Offset(size.width * 0.20, size.height * 0.62),
      Offset(size.width * 0.40, size.height * 0.70),
      Offset(size.width * 0.58, size.height * 0.42),
      Offset(size.width * 0.78, size.height * 0.48),
      Offset(size.width * 0.98, size.height * 0.18),
    ];

    final linePath = Path();

    linePath.moveTo(
      points.first.dx,
      points.first.dy,
    );

    for (int i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];

      final controlPoint1 = Offset(
        (previous.dx + current.dx) / 2,
        previous.dy,
      );

      final controlPoint2 = Offset(
        (previous.dx + current.dx) / 2,
        current.dy,
      );

      linePath.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        current.dx,
        current.dy,
      );
    }

    final fillPath = Path.from(linePath);

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    final pointPaint = Paint()
      ..color = AppColors.steelBlue
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);

      canvas.drawCircle(
        point,
        7,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );

      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}