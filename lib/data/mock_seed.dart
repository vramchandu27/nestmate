import '../models/advance.dart';
import '../models/association.dart';
import '../models/bill.dart';
import '../models/building.dart';
import '../models/community_post.dart';
import '../models/expense.dart';
import '../models/flat.dart';
import '../models/issue_report.dart';
import '../models/month_data.dart';
import '../models/water_month.dart';

/// In-memory seed data for the whole app. Numbers are chosen to reconcile
/// exactly with the build spec's worked July example: 29 tankers x ₹1,400,
/// 52,400 L total usage, flat 402 used 4,800 L (~₹3,719 water charge),
/// ₹19,402 common pool / 15 flats = ₹1,293 common share.
class MockSeed {
  MockSeed._();

  /// The flat number treated as "me" for the resident demo session.
  static const String demoResidentFlat = '402';

  static Building building() => Building(
    name: 'Sarovar Aavaas · Block 1',
    adminName: 'Ramana',
    upiId: '6281563991@ybl',
    photoAdded: true,
    setupComplete: true,
  );

  static Association association() => Association(
    code: 'SPV-2024',
    name: 'Shilpa Pine Valley',
    buildingCount: 20,
    joined: true,
  );

  static List<Flat> flats() => [
    Flat(
      flatNumber: '101',
      residentName: 'Ravi Kumar',
      phone: '+91 98765 10101',
      tankerExempt: true,
    ),
    Flat(
      flatNumber: '102',
      residentName: 'Priya Reddy',
      phone: '+91 98765 10102',
    ),
    Flat(
      flatNumber: '103',
      residentName: 'Suresh Babu',
      phone: '+91 98765 10103',
    ),
    Flat(
      flatNumber: '201',
      residentName: 'Latha Devi',
      phone: '+91 98765 10201',
    ),
    Flat(
      flatNumber: '202',
      residentName: 'Kiran Rao',
      phone: '+91 98765 10202',
    ),
    Flat(
      flatNumber: '203',
      residentName: 'Ramesh Naidu',
      phone: '+91 98765 10203',
    ),
    Flat(
      flatNumber: '301',
      residentName: 'Swathi Reddy',
      phone: '+91 98765 10301',
    ),
    Flat(
      flatNumber: '302',
      residentName: 'Venkatesh Rao',
      phone: '+91 98765 10302',
    ),
    Flat(
      flatNumber: '303',
      residentName: 'Anitha Kumari',
      phone: '+91 98765 10303',
    ),
    Flat(
      flatNumber: '401',
      residentName: 'Mohan Prasad',
      phone: '+91 98765 10401',
      tankerExempt: true,
    ),
    Flat(
      flatNumber: '402',
      residentName: 'Naresh Varma',
      phone: '+91 62815 63991',
      passwordSet: true,
    ),
    Flat(
      flatNumber: '403',
      residentName: 'Sita Lakshmi',
      phone: '+91 98765 10403',
      tankerExempt: true,
    ),
    Flat(
      flatNumber: '501',
      residentName: 'Ganesh Babu',
      phone: '+91 98765 10501',
    ),
    Flat(
      flatNumber: '502',
      residentName: 'Padma Priya',
      phone: '+91 98765 10502',
    ),
    Flat(
      flatNumber: '503',
      residentName: 'Chandra Sekhar',
      phone: '+91 98765 10503',
    ),
  ];

  static MonthData currentMonth() {
    final expenses = [
      Expense(id: 'exp1', name: 'Watchman salary', category: 'Watchman', amountPaise: 750000),
      Expense(
        id: 'exp2',
        name: 'Common electricity (incl. borewell pump)',
        category: 'Common electricity',
        amountPaise: 355000,
      ),
      Expense(id: 'exp3', name: 'Diesel (generator)', category: 'Diesel', amountPaise: 150400),
      Expense(id: 'exp4', name: 'CCTV repair', category: 'CCTV', amountPaise: 90000),
      Expense(id: 'exp5', name: 'Wifi', category: 'Wifi', amountPaise: 54800),
      Expense(id: 'exp6', name: 'Association fee', category: 'Association fee', amountPaise: 150000),
      Expense(id: 'exp7', name: 'Trash collection', category: 'Trash collection', amountPaise: 120000),
      Expense(
        id: 'exp8',
        name: 'Sump cleaning',
        category: 'Sump cleaning',
        amountPaise: 200000,
        paidByFlatNumber: '402',
      ),
      Expense(id: 'exp9', name: 'Plumbing minor repair', category: 'Plumbing', amountPaise: 70000),
    ];

    final advances = [
      Advance(
        id: 'adv1',
        reason: 'Hospital advance',
        givenToName: 'Ramana',
        amountPaise: 300000,
        recoveries: [
          AdvanceRecovery(flatNumber: '203', amountPaise: 100000),
          AdvanceRecovery(flatNumber: '303', amountPaise: 200000),
        ],
      ),
    ];

    final water = WaterMonthConfig(tankerCount: 29, pricePerTankerPaise: 140000);

    // (flatNumber, initialLitres, finalLitres) — flat 402 matches the
    // build spec's worked example exactly (155,600 -> 160,400 = 4,800 L).
    const readingRows = [
      ('101', 98200, 101000),
      ('102', 145300, 148500),
      ('103', 210700, 214300),
      ('201', 76900, 79900),
      ('202', 189400, 192000),
      ('203', 132100, 135500),
      ('301', 54300, 57200),
      ('302', 320900, 327000),
      ('303', 110600, 115600),
      ('401', 67200, 69600),
      ('402', 155600, 160400),
      ('403', 89500, 91700),
      ('501', 241000, 245800),
      ('502', 102400, 105100),
      ('503', 177900, 180800),
    ];
    final readings = readingRows
        .map(
          (r) => MeterReading(
            flatNumber: r.$1,
            initialLitres: r.$2,
            finalLitres: r.$3,
          ),
        )
        .toList();

    return MonthData(
      id: '2026-07',
      label: 'July 2026',
      expenses: expenses,
      advances: advances,
      water: water,
      readings: readings,
    );
  }

  /// Simplified historical months — just enough to show "earlier months"
  /// on the resident bill screen. Full itemized history is Phase 2.
  static List<MonthData> pastMonths() => [
    MonthData(
      id: '2026-06',
      label: 'June 2026',
      bills: [
        Bill(
          flatNumber: demoResidentFlat,
          monthId: '2026-06',
          commonSharePaise: 410000,
          status: BillStatus.confirmed,
        ),
      ],
      generated: true,
    ),
    MonthData(
      id: '2026-05',
      label: 'May 2026',
      bills: [
        Bill(
          flatNumber: demoResidentFlat,
          monthId: '2026-05',
          commonSharePaise: 390000,
          status: BillStatus.confirmed,
        ),
      ],
      generated: true,
    ),
  ];

  static List<CommunityPost> communityPosts() => [
    CommunityPost(
      id: 'post1',
      authorName: 'Association Committee',
      pinned: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      title: 'Water supply maintenance — Sunday',
      body:
          'Main line cleaning across all buildings this Sunday 10 AM–2 PM. '
          'Please store water in advance. Tankers arranged for emergencies.',
      likeCount: 12,
      comments: [
        Comment(authorName: 'Ravi · 101', text: 'Thanks for the heads up 🙏'),
        Comment(
          authorName: 'Latha · 201',
          text: 'Will the tanker cover Block C too?',
        ),
      ],
    ),
    CommunityPost(
      id: 'post2',
      authorName: 'Association Committee',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      title: 'Diwali celebration — 5 Nov',
      body:
          'Community Diwali event at the central park, 6 PM onwards. Snacks '
          'and cultural programs for kids. All 20 buildings welcome!',
      likeCount: 34,
    ),
    CommunityPost(
      id: 'post3',
      authorName: 'Association Committee',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      title: 'Association meeting minutes',
      body:
          'Minutes from the monthly meeting are now available. Key '
          'decisions: security upgrade approved, new play area for Phase 2.',
      likeCount: 19,
    ),
  ];

  static List<IssueReport> issues() => [
    IssueReport(
      id: 'issue1',
      title: 'Drainage leak',
      type: 'Drainage',
      location: 'Block 1 · Ground floor',
      flatNumber: demoResidentFlat,
      status: IssueStatus.inProgress,
    ),
    IssueReport(
      id: 'issue2',
      title: 'Corridor light',
      type: 'Electrical',
      location: 'Block 1 · 4th floor',
      flatNumber: demoResidentFlat,
      status: IssueStatus.resolved,
    ),
  ];
}
