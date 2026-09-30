import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/mock_seed.dart';
import '../models/advance.dart';
import '../models/association.dart';
import '../models/bill.dart';
import '../models/building.dart';
import '../models/community_post.dart';
import '../models/expense.dart';
import '../models/flat.dart';
import '../models/issue_report.dart';
import '../models/month_data.dart';
import '../models/reserve_contribution.dart';
import '../models/water_month.dart';
import '../models/work_item.dart';
import '../utils/phone.dart';

/// Owns the whole dataset for the single building this app manages: the
/// building itself, its flats, the association it may have joined, the
/// community feed, issue reports, and the current billing month (expenses,
/// advances, water readings, generated bills).
///
/// Backed by Firestore: `buildings/{buildingId}` plus its `flats`, `issues`, `posts`,
/// and `months/{monthId}` subcollections (the last with its own `expenses`,
/// `advances`, `readings`, `bills` subcollections — kept separate from the
/// month doc so a resident's screenshot upload and an admin's confirm can
/// never clobber each other). This app has only ever managed one building at
/// a time — there is no UI to pick between several — so `main` is a fixed,
/// well-known document id rather than a generated one.
///
/// [SocietyProvider()] starts empty and attaches live Firestore listeners
/// only once Firebase Auth reports someone signed in (the security rules
/// require it for every read, so attaching any earlier would just throw
/// permission-denied) — see [_watchAuthState]. [SocietyProvider.mock()]
/// keeps the old fully-synchronous, seeded-from-memory behavior with no
/// Firestore access at all, so the widget test suite doesn't need a Firebase
/// backend.
class SocietyProvider extends ChangeNotifier {
  SocietyProvider()
    : _mock = false,
      _building = Building(),
      _flats = [],
      _association = Association(),
      _posts = [],
      _issues = [],
      _workItems = [],
      _currentMonth = MonthData(id: '', label: ''),
      _pastMonths = [] {
    _watchAuthState();
  }

  SocietyProvider.mock()
    : _mock = true,
      // Mock mode never touches Firestore, but screens still gate on
      // hasBuilding, so give it the legacy id.
      _buildingId = legacyBuildingId,
      _building = MockSeed.building(),
      _flats = MockSeed.flats(),
      _association = MockSeed.association(),
      _posts = MockSeed.communityPosts(),
      _issues = MockSeed.issues(),
      _workItems = MockSeed.workItems(),
      _currentMonth = MockSeed.currentMonth(),
      _pastMonths = MockSeed.pastMonths();

  final bool _mock;

  /// True only for [SocietyProvider.mock()] (widget tests / no Firebase
  /// backend) — gates the demo-flat fallback in [completeSignIn]'s login
  /// path so a real, never-registered phone number never silently signs
  /// someone into an unrelated existing flat's real data.
  bool get isMock => _mock;

  /// The one building that existed before this app supported more than a
  /// single society. Used only as the migration fallback in
  /// [_resolveBuildingIdForUser], for accounts created before
  /// `users/{uid}.buildingId` started being written.
  static const String legacyBuildingId = 'main';

  /// Which society this signed-in user belongs to. Null until resolved
  /// (and for a signed-out or personal-tracker-only user, who has no
  /// building at all) — every Firestore path below hangs off it, so
  /// listeners must not attach until it's known.
  String? _buildingId;

  /// The signed-in user's society, or null if they aren't in one.
  String? get buildingId => _buildingId;

  /// False for a signed-out user and for a personal-tracker-only user —
  /// screens that read building data should not be reachable then.
  bool get hasBuilding => _buildingId != null;

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _buildingRef {
    final id = _buildingId;
    if (id == null) {
      // Every caller below runs post-login, once a society is resolved.
      // Failing loudly here beats silently reading or writing the wrong
      // society's data.
      throw StateError('No building attached: resolve a buildingId first.');
    }
    return _firestore.collection('buildings').doc(id);
  }
  CollectionReference<Map<String, dynamic>> get _flatsRef =>
      _buildingRef.collection('flats');
  CollectionReference<Map<String, dynamic>> get _issuesRef =>
      _buildingRef.collection('issues');
  CollectionReference<Map<String, dynamic>> get _workItemsRef =>
      _buildingRef.collection('workItems');
  CollectionReference<Map<String, dynamic>> get _reserveContributionsRef =>
      _buildingRef.collection('reserveContributions');
  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _buildingRef.collection('posts');
  CollectionReference<Map<String, dynamic>> get _monthsRef =>
      _buildingRef.collection('months');
  DocumentReference<Map<String, dynamic>> get _currentMonthRef =>
      _monthsRef.doc(_currentMonth.id);
  CollectionReference<Map<String, dynamic>> get _expensesRef =>
      _currentMonthRef.collection('expenses');
  CollectionReference<Map<String, dynamic>> get _advancesRef =>
      _currentMonthRef.collection('advances');
  CollectionReference<Map<String, dynamic>> get _readingsRef =>
      _currentMonthRef.collection('readings');
  CollectionReference<Map<String, dynamic>> get _billsRef =>
      _currentMonthRef.collection('bills');

  StreamSubscription<User?>? _authSub;
  String? _attachedUid;
  final List<StreamSubscription> _subs = [];
  final List<StreamSubscription> _monthSubs = [];

  /// The security rules require sign-in for every read, so listeners can
  /// only be attached once someone's actually signed in — attaching them
  /// at construction (before any auth has happened) throws permission-
  /// denied on every one of them. Firebase Auth's own state stream is the
  /// simplest source of truth for "is it safe to read yet."
  ///
  /// Tracks *which* uid the current listeners belong to (not just
  /// signed-in/signed-out) — this app lets a resident and an admin sign in
  /// on the same device one after another without an intermediate sign-out
  /// (each OTP verification just calls signInWithCredential again), so a
  /// plain null-check would miss that switch and leave stale listeners
  /// running under a session that never got a fresh initial read.
  void _watchAuthState() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null && user.uid != _attachedUid) {
        _attachedUid = user.uid;
        _detachTopLevelListeners();
        // Which society this user belongs to has to be read before any
        // listener can attach — every path hangs off the building id.
        final resolved = await _resolveBuildingIdForUser(user);
        // Another sign-in may have landed while that read was in flight
        // (this app switches accounts without an intermediate sign-out);
        // if so, that later callback owns the state now.
        if (_attachedUid != user.uid) return;
        _buildingId = null;
        if (resolved != null) {
          attachToBuilding(resolved);
        } else {
          notifyListeners();
        }
      } else if (user == null && _attachedUid != null) {
        _attachedUid = null;
        _buildingId = null;
        _detachTopLevelListeners();
      }
    });
  }

  /// Works out which society a signed-in user belongs to:
  /// 1. `users/{uid}.buildingId` — written when they join, the normal case.
  /// 2. A building whose `adminPhone` is theirs — covers an admin whose
  ///    account predates that field being written.
  /// 3. [legacyBuildingId] — the migration fallback for residents who
  ///    signed up before this app supported multiple societies, but ONLY
  ///    for someone who is genuinely in it (see [_belongsToLegacyBuilding]).
  ///
  /// Returns null for a phone that belongs to no society yet — a brand-new
  /// admin who hasn't created one, or a personal-tracker user. That null
  /// matters: this step used to fall back to [legacyBuildingId]
  /// unconditionally, which meant every unrecognized phone in the world
  /// resolved to that one society. A new admin was then told it "already
  /// has an admin" (it does — someone else's), and a new resident would
  /// have been pointed at a building they have nothing to do with.
  Future<String?> _resolveBuildingIdForUser(User user) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 8));
      final recorded = userDoc.data()?['buildingId'] as String?;
      if (recorded != null && recorded.isNotEmpty) return recorded;

      final phone = user.phoneNumber;
      if (phone != null && phone.isNotEmpty) {
        final owned = await _firestore
            .collection('buildings')
            .where('adminPhone', isEqualTo: toE164Phone(phone))
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 8));
        if (owned.docs.isNotEmpty) {
          final id = owned.docs.first.id;
          await rememberBuildingForCurrentUser(id);
          return id;
        }
      }

      if (await _belongsToLegacyBuilding(user)) {
        await rememberBuildingForCurrentUser(legacyBuildingId);
        return legacyBuildingId;
      }
    } catch (e) {
      debugPrint('SocietyProvider._resolveBuildingIdForUser: $e');
    }
    return null;
  }

  /// Whether [user] is really in the pre-multi-society building — either
  /// already enrolled there, or holding one of its flats by phone. Both
  /// reads are ones the security rules allow a non-member to make about
  /// themselves specifically (`members/{own uid}`, and flats filtered to
  /// their own phone), so this stays safe for a stranger to call: for
  /// someone from another apartment both simply come back empty.
  Future<bool> _belongsToLegacyBuilding(User user) async {
    final legacy = _firestore.collection('buildings').doc(legacyBuildingId);
    final member = await legacy
        .collection('members')
        .doc(user.uid)
        .get()
        .timeout(const Duration(seconds: 8));
    if (member.exists) return true;

    final phone = user.phoneNumber;
    if (phone == null || phone.isEmpty) return false;
    final flats = await legacy
        .collection('flats')
        .where('phone', isEqualTo: toE164Phone(phone))
        .limit(1)
        .get()
        .timeout(const Duration(seconds: 8));
    return flats.docs.isNotEmpty;
  }

  /// Caches which society this user belongs to, so later logins resolve in
  /// a single read instead of re-deriving it (and so a resident never has
  /// to enter their join code again).
  Future<void> rememberBuildingForCurrentUser(String buildingId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _mock) return;
    await _firestore.collection('users').doc(uid).set({
      'buildingId': buildingId,
    }, SetOptions(merge: true));
  }

  void _detachTopLevelListeners() {
    _listenersAttached = false;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    for (final s in _monthSubs) {
      s.cancel();
    }
    _monthSubs.clear();
    _building = Building();
    _flats = [];
    _association = Association();
    _posts = [];
    _issues = [];
    _workItems = [];
    _reserveContributions = [];
    _currentMonth = MonthData(id: '', label: '');
    _pastMonths = [];
    notifyListeners();
  }

  void _attachTopLevelListeners() {
    _subs.add(
      _buildingRef.snapshots().listen((snap) {
        final data = snap.data();
        final newBuilding = data != null ? Building.fromMap(data) : Building();
        final oldMonthId = _building.currentMonthId;
        _building = newBuilding;
        final assocMap = data?['association'];
        _association = assocMap != null
            ? Association.fromMap(Map<String, dynamic>.from(assocMap as Map))
            : Association();
        if (newBuilding.currentMonthId.isNotEmpty &&
            newBuilding.currentMonthId != oldMonthId) {
          _attachMonthListeners(newBuilding.currentMonthId);
        }
        // Deliberately not gated on the month actually having changed —
        // relying on an in-memory equality check against whatever
        // happened to be cached at that exact instant is fragile (a
        // missed or reordered snapshot, e.g. from Firestore's offline
        // cache delivering stale data first, silently leaves this stale
        // forever with no way to recover). Re-running this on every
        // building update is a handful of extra reads at this scale, and
        // guarantees "earlier months" can never get stuck out of date.
        if (newBuilding.currentMonthId.isNotEmpty) {
          _refreshPastMonths();
        }
        notifyListeners();
      }, onError: (Object e) => debugPrint('SocietyProvider building listener: $e')),
    );
    _subs.add(
      _flatsRef.snapshots().listen((snap) {
        _flats = snap.docs.map((d) => Flat.fromMap(d.data())).toList();
        notifyListeners();
      }, onError: (Object e) => debugPrint('SocietyProvider flats listener: $e')),
    );
    _subs.add(
      _issuesRef.snapshots().listen((snap) {
        _issues = snap.docs.map((d) => IssueReport.fromMap(d.data())).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
      }, onError: (Object e) => debugPrint('SocietyProvider issues listener: $e')),
    );
    _subs.add(
      _postsRef.snapshots().listen((snap) {
        _posts = snap.docs.map((d) => CommunityPost.fromMap(d.data())).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
      }, onError: (Object e) => debugPrint('SocietyProvider posts listener: $e')),
    );
    _subs.add(
      _workItemsRef.snapshots().listen((snap) {
        _workItems = snap.docs.map((d) => WorkItem.fromMap(d.data())).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
      }, onError: (Object e) => debugPrint('SocietyProvider work items listener: $e')),
    );
    _subs.add(
      _reserveContributionsRef.snapshots().listen((snap) {
        _reserveContributions = snap.docs
            .map((d) => ReserveContribution.fromMap(d.data()))
            .toList()
          ..sort((a, b) => b.collectedOn.compareTo(a.collectedOn));
        notifyListeners();
      }, onError: (Object e) =>
          debugPrint('SocietyProvider reserve contributions listener: $e')),
    );
  }

  void _attachMonthListeners(String monthId) {
    for (final s in _monthSubs) {
      s.cancel();
    }
    _monthSubs.clear();
    _currentMonth = MonthData(id: monthId, label: monthId);

    final monthRef = _monthsRef.doc(monthId);
    _monthSubs.add(
      monthRef.snapshots().listen((snap) {
        final data = snap.data();
        if (data != null) {
          final fresh = MonthData.fromMap(data);
          _currentMonth.label = fresh.label;
          _currentMonth.water = fresh.water;
          _currentMonth.generated = fresh.generated;
          _currentMonth.generatedAt = fresh.generatedAt;
          _currentMonth.flatCountAtGeneration = fresh.flatCountAtGeneration;
          _currentMonth.frozenTotalUsageLitres = fresh.frozenTotalUsageLitres;
          _currentMonth.frozenTotalTankerCostPaise =
              fresh.frozenTotalTankerCostPaise;
        }
        notifyListeners();
      }, onError: (Object e) => debugPrint('SocietyProvider month listener: $e')),
    );
    _monthSubs.add(
      monthRef.collection('expenses').snapshots().listen((snap) {
        _currentMonth.expenses = snap.docs
            .map((d) => Expense.fromMap(d.data()))
            .toList();
        notifyListeners();
      }, onError: (Object e) => debugPrint('SocietyProvider expenses listener: $e')),
    );
    _monthSubs.add(
      monthRef.collection('advances').snapshots().listen((snap) {
        _currentMonth.advances = snap.docs
            .map((d) => Advance.fromMap(d.data()))
            .toList();
        notifyListeners();
      }, onError: (Object e) => debugPrint('SocietyProvider advances listener: $e')),
    );
    _monthSubs.add(
      monthRef.collection('readings').snapshots().listen((snap) {
        _currentMonth.readings = snap.docs
            .map((d) => MeterReading.fromMap(d.data()))
            .toList();
        notifyListeners();
      }, onError: (Object e) => debugPrint('SocietyProvider readings listener: $e')),
    );
    _attachBillsListener(monthRef);
  }

  /// The security rules only let a resident read their *own* flat's bill
  /// doc, not the whole `bills` collection — an unfiltered collection
  /// query like the admin uses can't be proven safe for every document it
  /// might return, so Firestore rejects the whole listener outright for a
  /// resident. Try the admin-shaped collection listener first; if it's
  /// denied, fall back to listening to just this user's own bill doc,
  /// which is all a resident ever needs (`billForResident` only looks up
  /// their own flat anyway).
  void _attachBillsListener(DocumentReference<Map<String, dynamic>> monthRef) {
    late final StreamSubscription collectionSub;
    collectionSub = monthRef.collection('bills').snapshots().listen((snap) {
      _currentMonth.bills = snap.docs.map((d) => Bill.fromMap(d.data())).toList();
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('SocietyProvider bills listener: $e');
      _monthSubs.remove(collectionSub);
      final myFlat = _myFlatNumber;
      if (myFlat == null) return;
      _monthSubs.add(
        monthRef.collection('bills').doc(myFlat).snapshots().listen((doc) {
          final data = doc.data();
          _currentMonth.bills = data != null ? [Bill.fromMap(data)] : [];
          notifyListeners();
        }, onError: (Object e) => debugPrint('SocietyProvider own-bill listener: $e')),
      );
    });
    _monthSubs.add(collectionSub);
  }

  /// The flat belonging to whoever is currently signed in, found by
  /// matching their verified phone (from the Auth token, E.164) against
  /// the flats roster — mirrors the same phone-based ownership the
  /// security rules use, without needing a separate profile doc.
  String? get _myFlatNumber {
    final myPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (myPhone == null) return null;
    final normalized = _normalizedPhone(myPhone);
    for (final f in _flats) {
      if (_normalizedPhone(f.phone) == normalized) return f.flatNumber;
    }
    return null;
  }

  /// Historical months are read once (not live-listened — they're frozen)
  /// whenever [Building.currentMonthId] changes, including their `bills`
  /// subcollection so [pastBillsForFlat] can stay a plain synchronous getter.
  Future<void> _refreshPastMonths() async {
    try {
      final snap = await _monthsRef
          .orderBy('id', descending: true)
          .get()
          .timeout(const Duration(seconds: 8));
      final result = <MonthData>[];
      for (final doc in snap.docs) {
        if (doc.id == _currentMonth.id) continue;
        final month = MonthData.fromMap(doc.data());
        month.bills = await _fetchPastMonthBills(doc.reference);
        result.add(month);
      }
      _pastMonths = result;
      notifyListeners();
    } catch (e) {
      debugPrint('SocietyProvider _refreshPastMonths: $e');
    }
  }

  /// Mirrors [_attachBillsListener]'s admin/resident fallback: the security
  /// rules only let a resident read their *own* bill doc, not the whole
  /// `bills` subcollection, so this unfiltered collection read can't be
  /// proven safe for a resident and Firestore denies it outright (even
  /// though one of the 15 docs is theirs). Without this fallback, that
  /// denial was silently swallowed by the caller's try/catch, leaving a
  /// resident's "earlier months" permanently empty.
  Future<List<Bill>> _fetchPastMonthBills(
    DocumentReference<Map<String, dynamic>> monthRef,
  ) async {
    try {
      final billsSnap = await monthRef
          .collection('bills')
          .get()
          .timeout(const Duration(seconds: 8));
      return billsSnap.docs.map((b) => Bill.fromMap(b.data())).toList();
    } catch (e) {
      final myFlat = _myFlatNumber;
      if (myFlat == null) return [];
      final doc = await monthRef.collection('bills').doc(myFlat).get();
      final data = doc.data();
      return data != null ? [Bill.fromMap(data)] : [];
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    for (final s in _monthSubs) {
      s.cancel();
    }
    super.dispose();
  }

  Building _building;
  List<Flat> _flats;
  Association _association;
  List<CommunityPost> _posts;
  List<IssueReport> _issues;
  List<WorkItem> _workItems;
  List<ReserveContribution> _reserveContributions = [];
  MonthData _currentMonth;
  List<MonthData> _pastMonths;

  // ── Read access ──────────────────────────────────────────────────────
  Building get building => _building;
  List<Flat> get flats => List.unmodifiable(_flats);
  Association get association => _association;
  List<CommunityPost> get posts => List.unmodifiable(_posts);
  List<IssueReport> get issues => List.unmodifiable(_issues);
  List<WorkItem> get workItems => List.unmodifiable(_workItems);
  /// Who has paid into the reserve fund, newest first.
  List<ReserveContribution> get reserveContributions =>
      List.unmodifiable(_reserveContributions);

  /// Everything ever paid in, which is not the balance — reserve-funded
  /// expenses draw the balance down without touching these records.
  int get reserveCollectedPaise =>
      _reserveContributions.fold(0, (total, c) => total + c.amountPaise);

  int get pendingWorkItemCount => _workItems.where((w) => !w.isDone).length;
  MonthData get currentMonth => _currentMonth;
  List<MonthData> get pastMonths => List.unmodifiable(_pastMonths);

  Flat? flatByNumber(String flatNumber) {
    for (final f in _flats) {
      if (f.flatNumber == flatNumber) return f;
    }
    return null;
  }

  List<IssueReport> issuesForFlat(String flatNumber) =>
      _issues.where((i) => i.flatNumber == flatNumber).toList();

  /// Finds the flat whose stored phone matches [phone] — how a returning
  /// resident's flat is resolved on login when no explicit flat number is
  /// given (the flat's phone was set once, at signup, via
  /// [claimFlatForSignup]).
  Future<Flat?> findFlatByPhone(String phone) async {
    if (_mock) {
      final normalized = _normalizedPhone(phone);
      for (final f in _flats) {
        if (_normalizedPhone(f.phone) == normalized) return f;
      }
      return null;
    }
    try {
      final snap = await _flatsRef
          .where('phone', isEqualTo: toE164Phone(phone))
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));
      if (snap.docs.isEmpty) return null;
      return Flat.fromMap(snap.docs.first.data());
    } catch (_) {
      // A read that timed out found nothing, same as a genuine miss — the
      // caller must never hang indefinitely waiting on a login attempt.
      return null;
    }
  }

  /// Derived view matching the spec's `building.exemptFlats[]` shape — the
  /// source of truth is still each [Flat.tankerExempt] bool (set per-flat
  /// when it's added), this just exposes it as the list shape.
  List<String> get exemptFlatNumbers =>
      _flats.where((f) => f.tankerExempt).map((f) => f.flatNumber).toList();

  /// Every past month's bill for a flat, most recent first — regardless of
  /// payment status, so the resident's "earlier months" history still
  /// shows a month they never paid. See [totalPaidPaiseForFlat] for the
  /// confirmed-only sum.
  List<Bill> pastBillsForFlat(String flatNumber) {
    final result = <Bill>[];
    for (final month in _pastMonths) {
      final bill = month.billFor(flatNumber);
      if (bill != null) result.add(bill);
    }
    return result;
  }

  /// What the resident profile's "Paid so far" shows — every *confirmed*
  /// payment for this flat, including the current month's if the admin has
  /// already confirmed it. [pastBillsForFlat] alone under-counts this: it
  /// excludes the current month entirely (by design, for the history list)
  /// and includes unconfirmed old bills too.
  int totalPaidPaiseForFlat(String flatNumber) {
    final pastPaidPaise = pastBillsForFlat(flatNumber)
        .where((b) => b.status == BillStatus.confirmed)
        .fold<int>(0, (total, b) => total + b.amountDuePaise);
    final current = _currentMonth.billFor(flatNumber);
    final currentPaidPaise =
        current != null && current.status == BillStatus.confirmed
        ? current.amountDuePaise
        : 0;
    return pastPaidPaise + currentPaidPaise;
  }

  // ── Water calc (derived) ────────────────────────────────────────────
  WaterCalcResult get waterCalc =>
      computeWaterCalc(_currentMonth.water, _currentMonth.readings);

  int waterChargePaiseFor(String flatNumber) {
    if (!_building.waterMetered) return 0;
    final flat = flatByNumber(flatNumber);
    if (flat == null || flat.tankerExempt) return 0;
    final reading = _currentMonth.readingFor(flatNumber);
    if (reading == null) return 0;
    return waterCalc.waterChargePaiseForLitres(reading.usageLitres);
  }

  // ── Common pool / offsets / advances (derived) ─────────────────────
  int get commonPoolPaise => _currentMonth.commonPoolPaise;

  int get commonSharePaisePerFlat =>
      _flats.isEmpty ? 0 : (commonPoolPaise / _flats.length).round();

  int offsetCreditsPaiseFor(String flatNumber) {
    var total = 0;
    for (final e in _currentMonth.expenses) {
      if (e.paidByFlatNumber == flatNumber) total += e.amountPaise;
    }
    return total;
  }

  /// Live-computed bill for a flat from the current month's data — does
  /// not require [generateBills] to have been called yet, so admin preview
  /// screens can always show an up-to-date number. Resident-facing screens
  /// should use [billForResident] instead, which freezes once generated.
  Bill computeBillDraft(String flatNumber) {
    final flat = flatByNumber(flatNumber);
    return Bill(
      flatNumber: flatNumber,
      monthId: _currentMonth.id,
      openingBalancePaise: flat?.openingBalancePaise ?? 0,
      waterChargePaise: waterChargePaiseFor(flatNumber),
      commonSharePaise: commonSharePaisePerFlat,
      offsetCreditsPaise: offsetCreditsPaiseFor(flatNumber),
      status: _currentMonth.billFor(flatNumber)?.status ?? BillStatus.unpaid,
      screenshotAdded:
          _currentMonth.billFor(flatNumber)?.screenshotAdded ?? false,
    );
  }

  /// Whether the admin has generated this month's bills yet. Residents
  /// shouldn't be able to pay against a number that can still move.
  bool get billsGenerated => _currentMonth.generated;

  /// The bill a resident should see and pay against: the frozen, generated
  /// bill once one exists, otherwise a live draft (pre-generation, for
  /// display only — [billsGenerated] gates whether paying is allowed).
  Bill billForResident(String flatNumber) {
    if (_currentMonth.generated) {
      final frozen = _currentMonth.billFor(flatNumber);
      if (frozen != null) return frozen;
    }
    return computeBillDraft(flatNumber);
  }

  // ── Collection stats (admin dashboard) ──────────────────────────────
  int get totalDuePaise => _flats.fold(
    0,
    (total, f) => total + computeBillDraft(f.flatNumber).amountDuePaise,
  );

  int get collectedPaise => _currentMonth.bills
      .where((b) => b.status == BillStatus.confirmed)
      .fold(0, (total, b) => total + b.amountDuePaise);

  int get pendingPaise => totalDuePaise - collectedPaise;

  double get collectionPercent {
    if (totalDuePaise <= 0) return 0;
    return (collectedPaise / totalDuePaise).clamp(0, 1).toDouble();
  }

  int get paidFlatCount =>
      _currentMonth.bills.where((b) => b.status == BillStatus.confirmed).length;

  // ── Multi-society: create, find, join ────────────────────────────────

  /// Points this provider at [buildingId] and starts listening to it —
  /// called once a society is resolved (login) or created/joined (signup).
  /// Whether [_attachTopLevelListeners] is currently running for
  /// [_buildingId] — signup resolves a society *before* the user is signed
  /// in (to validate a join code without sending an SMS first), and every
  /// read needs auth, so pointing at a society and listening to it are two
  /// separate steps.
  bool _listenersAttached = false;

  void attachToBuilding(String buildingId) {
    if (_buildingId == buildingId && _listenersAttached) return;
    _detachTopLevelListeners();
    _listenersAttached = false;
    _buildingId = buildingId;
    if (!_mock && FirebaseAuth.instance.currentUser != null) {
      _attachTopLevelListeners();
      _listenersAttached = true;
    }
    notifyListeners();
  }

  /// Resolves and attaches this user's society if it isn't already, and
  /// returns its id. [_watchAuthState] does the same thing on its own, but
  /// asynchronously — sign-in runs immediately after `signInWithCredential`
  /// and needs the society *now*, so it awaits this rather than racing that
  /// listener. Safe to call repeatedly; it's a no-op once attached.
  Future<String?> ensureBuildingAttached() async {
    // Mock mode has no Firebase app at all — touching FirebaseAuth here
    // throws [core/no-app] and takes the widget tests down with it.
    if (_mock) return _buildingId;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildingId;
    // Already pointed at a society (e.g. signup resolved it from a join
    // code before sign-in) — just start listening now that auth exists.
    final known = _buildingId;
    if (known != null) {
      if (!_listenersAttached) attachToBuilding(known);
      return known;
    }
    final resolved = await _resolveBuildingIdForUser(user);
    if (resolved != null) attachToBuilding(resolved);
    return resolved;
  }

  /// Creates a brand-new society owned by [adminPhone] and attaches to it.
  /// The name, UPI id and join code are filled in afterwards by
  /// [completeBlockSetup] — this just establishes the document and its
  /// admin so the rest of setup has somewhere to write.
  ///
  /// Returns the new building's id.
  Future<String> createBuildingForAdmin(String adminPhone) async {
    final e164 = toE164Phone(adminPhone.trim());
    if (_mock) {
      _building.adminPhone = e164;
      notifyListeners();
      return legacyBuildingId;
    }
    // Re-running signup (or signing up on a second device) must not mint a
    // duplicate society — if this phone already owns one, reuse it.
    final existing = await _firestore
        .collection('buildings')
        .where('adminPhone', isEqualTo: e164)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      final id = existing.docs.first.id;
      attachToBuilding(id);
      await rememberBuildingForCurrentUser(id);
      return id;
    }
    final ref = _firestore.collection('buildings').doc();
    await ref.set({
      'name': '',
      'adminPhone': e164,
      'setupComplete': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    attachToBuilding(ref.id);
    await rememberBuildingForCurrentUser(ref.id);
    return ref.id;
  }

  /// Resolves a resident-facing join code to the society it belongs to, or
  /// null if no society uses that code. Reads a small `joinCodes/{code}`
  /// lookup document rather than querying every building, so a resident
  /// never needs read access to societies they don't belong to.
  Future<String?> findBuildingIdByJoinCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    if (_mock) {
      return _building.joinCode.toUpperCase() == normalized
          ? legacyBuildingId
          : null;
    }
    try {
      final doc = await _firestore
          .collection('joinCodes')
          .doc(normalized)
          .get()
          .timeout(const Duration(seconds: 8));
      return doc.data()?['buildingId'] as String?;
    } catch (e) {
      debugPrint('SocietyProvider.findBuildingIdByJoinCode: $e');
      return null;
    }
  }

  /// Records this user as a member of [buildingId]. This document is what
  /// the security rules check — without it a resident can't read their own
  /// society's data, so it's written on join *and* refreshed on every
  /// login (cheap, and it backfills accounts created before this existed).
  Future<void> recordMembership({
    required String buildingId,
    required String flatNumber,
    required String phone,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _mock) return;
    try {
      await _firestore
          .collection('buildings')
          .doc(buildingId)
          .collection('members')
          .doc(uid)
          .set({
            'flatNumber': flatNumber,
            'phone': toE164Phone(phone),
            'joinedAt': DateTime.now().millisecondsSinceEpoch,
          }, SetOptions(merge: true));
    } catch (e) {
      // Never block a login on this — the rules stay permissive until
      // every existing user has one (see the two-step rollout).
      debugPrint('SocietyProvider.recordMembership: $e');
    }
  }

  // ── Mutations: setup ─────────────────────────────────────────────────
  Future<void> completeBlockSetup({
    required String name,
    required String adminName,
    String? collectorName,
    required String upiId,
    bool photoAdded = false,
    String? photoUrl,
    bool? waterMetered,
    bool? committeeEnabled,
    String? defaultLang,
  }) async {
    final wasAlreadySetUp = _building.setupComplete;
    final now = DateTime.now();
    var currentMonthId = _building.currentMonthId;
    var currentMonthLabel = '';
    if (currentMonthId.isEmpty) {
      currentMonthId = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      currentMonthLabel = '${monthNames[now.month - 1]} ${now.year}';
    }

    final updated = Building(
      name: name,
      adminName: adminName,
      adminPhone: _building.adminPhone,
      collectorName: collectorName?.isNotEmpty == true
          ? collectorName!
          : adminName,
      upiId: upiId,
      photoAdded: photoAdded,
      // Deliberately no `?? _building.photoUrl` fallback here — the caller
      // must resolve the definitive final value itself (keep the existing
      // URL, a freshly uploaded one, or null for an explicit removal),
      // since null is ambiguous between "unchanged" and "cleared" and only
      // the caller knows which one actually happened.
      photoUrl: photoUrl,
      setupComplete: true,
      // Keep the existing join code/categories/creation info on an edit;
      // only generate fresh ones the first time this building is created.
      joinCode: wasAlreadySetUp ? _building.joinCode : _generateJoinCode(name),
      defaultLang: defaultLang ?? _building.defaultLang,
      waterMetered: waterMetered ?? _building.waterMetered,
      commonCategories: _building.commonCategories,
      committeeEnabled: committeeEnabled ?? _building.committeeEnabled,
      createdBy: wasAlreadySetUp ? _building.createdBy : adminName,
      createdAt: wasAlreadySetUp ? _building.createdAt : now,
      currentMonthId: currentMonthId,
    );

    if (_mock) {
      _building = updated;
      notifyListeners();
      return;
    }

    await _buildingRef.set(updated.toMap(), SetOptions(merge: true));
    if (currentMonthLabel.isNotEmpty) {
      await _monthsRef.doc(currentMonthId).set({
        'id': currentMonthId,
        'label': currentMonthLabel,
      }, SetOptions(merge: true));
    }
    // Publish the code → society lookup the moment a fresh code is minted,
    // so residents can join with it. Skipped on an edit, where the code is
    // carried over unchanged and its lookup already exists.
    if (!wasAlreadySetUp && updated.joinCode.isNotEmpty) {
      await _firestore
          .collection('joinCodes')
          .doc(updated.joinCode.toUpperCase())
          .set({'buildingId': _buildingRef.id});
    }
    if (!wasAlreadySetUp) {
      await _claimSocietyName(name);
    }
  }

  /// Normalized key for the society-name index: case and punctuation vary
  /// wildly between two people typing the same building's name ("Green
  /// Valley", "green valley apartments", "GreenValley"), so only letters
  /// and digits survive.
  static String _societyNameKey(String name) =>
      name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Whether some society already goes by [name].
  ///
  /// This exists for one failure mode: hand a building's WhatsApp group a
  /// Play Store link and two helpful people both tap "Create Account",
  /// ending up with two half-populated societies for one apartment and
  /// residents split across them. Nothing can tell two societies apart by
  /// name alone — two real buildings genuinely share names — so this only
  /// ever warns, never blocks.
  ///
  /// A miss (offline, permission, anything) answers false: a warning that
  /// can't be shown must not stop someone from creating their society.
  Future<bool> societyNameExists(String name) async {
    final key = _societyNameKey(name);
    if (key.isEmpty || _mock) return false;
    try {
      final doc = await _firestore
          .collection('societyNames')
          .doc(key)
          .get()
          .timeout(const Duration(seconds: 6));
      // A society re-running its own setup isn't a duplicate of itself.
      return doc.exists && doc.data()?['buildingId'] != _buildingId;
    } catch (e) {
      debugPrint('SocietyProvider.societyNameExists: $e');
      return false;
    }
  }

  /// Records this society in the name index so the next person typing the
  /// same name gets warned. Only the first claimant is stored — the index
  /// answers "does this name exist?", not "which societies use it" — so a
  /// later collision simply leaves the existing entry alone.
  Future<void> _claimSocietyName(String name) async {
    final key = _societyNameKey(name);
    if (key.isEmpty) return;
    try {
      final ref = _firestore.collection('societyNames').doc(key);
      if ((await ref.get().timeout(const Duration(seconds: 6))).exists) return;
      await ref.set({
        'buildingId': _buildingRef.id,
        'name': name,
      }).timeout(const Duration(seconds: 6));
    } catch (e) {
      // Indexing is a convenience for the *next* admin; never fail this
      // admin's setup over it.
      debugPrint('SocietyProvider._claimSocietyName: $e');
    }
  }

  static String _generateJoinCode(String buildingName) {
    final letters = buildingName.toUpperCase().replaceAll(
      RegExp(r'[^A-Z]'),
      '',
    );
    final prefix = (letters.isEmpty ? 'SAV' : letters)
        .padRight(3, 'X')
        .substring(0, 3);
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    final suffix = List.generate(
      4,
      (_) => chars[rand.nextInt(chars.length)],
    ).join();
    return '$prefix-$suffix';
  }

  /// Validates a resident signup attempt against the pre-added flat
  /// roster and, if it matches, claims the flat for this resident.
  ///
  /// This is the guard the spec requires: a resident can only self-serve
  /// signup against a flat + phone the admin already added — never a
  /// made-up flat number. Returns null on success, or a localization key
  /// describing the failure to show the user.
  ///
  /// The Firestore security rules mirror this exact check server-side (a
  /// resident can only update their own flat, matched by phone) — this
  /// client-side check is what turns a rules rejection into a friendly
  /// message instead of a raw permission error.
  Future<String?> claimFlatForSignup({
    required String flatNumber,
    required String phone,
    required String name,
  }) async {
    if (_mock) {
      final flat = flatByNumber(flatNumber.trim());
      if (flat == null) return 'flatNotFound';
      if (_normalizedPhone(flat.phone) != _normalizedPhone(phone)) {
        return 'flatPhoneMismatch';
      }
      flat.residentName = name.trim();
      flat.phone = phone.trim();
      flat.passwordSet = true;
      notifyListeners();
      return null;
    }

    final DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _flatsRef
          .doc(flatNumber.trim())
          .get()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Never leave the calling screen's loading overlay hanging forever
      // on a read that timed out or failed — surface it as a real error.
      return 'errorOccurred';
    }
    if (!doc.exists) return 'flatNotFound';
    final flat = Flat.fromMap(doc.data()!);
    if (_normalizedPhone(toE164Phone(flat.phone)) !=
        _normalizedPhone(toE164Phone(phone))) {
      return 'flatPhoneMismatch';
    }
    try {
      await doc.reference.update({
        'residentName': name.trim(),
        'phone': toE164Phone(phone.trim()),
        'passwordSet': true,
      }).timeout(const Duration(seconds: 8));
    } catch (_) {
      return 'errorOccurred';
    }
    return null;
  }

  /// Read-only version of the same check [claimFlatForSignup] does, with no
  /// write — lets a signup screen validate flat+phone before sending an SMS
  /// (no point verifying a phone number for a flat that doesn't exist), and
  /// crucially, without claiming the flat until the phone is actually
  /// verified by OTP afterward.
  Future<String?> checkFlatClaim({
    required String flatNumber,
    required String phone,
  }) async {
    if (_mock) {
      final flat = flatByNumber(flatNumber.trim());
      if (flat == null) return 'flatNotFound';
      if (!_phoneBelongsToFlat(flat, phone)) return 'flatPhoneMismatch';
      return null;
    }
    final DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await _flatsRef
          .doc(flatNumber.trim())
          .get()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // This is exactly what was hanging real logins: an unbounded await
      // on this read left the caller's loading overlay up forever with no
      // way out. Never again — a slow/failed read must surface as a real,
      // recoverable error instead of freezing the screen.
      return 'errorOccurred';
    }
    if (!doc.exists) return 'flatNotFound';
    final flat = Flat.fromMap(doc.data()!);
    if (!_phoneBelongsToFlat(flat, phone)) return 'flatPhoneMismatch';
    return null;
  }

  /// Whether [phone] may sign in for [flat] — its primary number or any
  /// co-resident's. A flat routinely holds two people who both use the
  /// app, so matching only the primary number turned the second person
  /// away with "that phone number doesn't match our records".
  bool _phoneBelongsToFlat(Flat flat, String phone) {
    final target = _normalizedPhone(toE164Phone(phone));
    return flat.allPhones.any(
      (p) => _normalizedPhone(toE164Phone(p)) == target,
    );
  }

  String _normalizedPhone(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Whether [phone] is allowed to hold the admin seat — true if no admin
  /// is bound yet (first to log in as admin claims it) or if it matches
  /// the already-bound admin. There is only ever one admin per building.
  ///
  /// Best-effort only, NOT the real gate: this reads [_building] in
  /// memory, which is still its unloaded default for anyone not yet signed
  /// in — so it always passes for a fresh phone until [claimAdminIfUnbound]
  /// does a real, authoritative Firestore read post-auth. This exists only
  /// to fail fast in the UI (skip sending an OTP that's doomed anyway) when
  /// the data happens to already be loaded (e.g. an admin re-logging in).
  bool canSignInAsAdmin(String phone) {
    if (_building.adminPhone.isEmpty) return true;
    return _normalizedPhone(toE164Phone(_building.adminPhone)) ==
        _normalizedPhone(toE164Phone(phone));
  }

  /// Binds [phone] as the admin if the seat is still unclaimed, or confirms
  /// it already belongs to [phone]. Reassignment to a *different* phone
  /// only happens via [transferAdmin]. Stored in E.164 form so it matches
  /// the phone number Firebase Auth puts in the ID token for the security
  /// rules.
  ///
  /// Returns whether [phone] legitimately holds the seat after this call —
  /// callers (admin login/signup) MUST check this before granting local
  /// admin access. This always does a fresh Firestore read rather than
  /// trusting the in-memory [_building] doc: that doc is still its unloaded
  /// default (`adminPhone == ''`) for anyone not yet signed in, since this
  /// provider's own listeners only attach once already authenticated —
  /// trusting it here would let any phone number that completes
  /// verification claim (or appear to claim) the seat.
  Future<bool> claimAdminIfUnbound(String phone) async {
    if (phone.trim().isEmpty) return false;
    final e164Phone = toE164Phone(phone.trim());

    if (_mock) {
      if (_building.adminPhone.isEmpty) {
        _building.adminPhone = e164Phone;
        notifyListeners();
        return true;
      }
      return _normalizedPhone(_building.adminPhone) == _normalizedPhone(e164Phone);
    }

    // No society resolved for this phone at all, so there is no seat to
    // claim or confirm. This is a brand-new admin who hasn't created their
    // society yet — they belong in admin signup, not here. Callers
    // distinguish this from "someone else holds the seat" by checking
    // [hasBuilding], so they can say which of the two actually happened.
    if (_buildingId == null) return false;

    Map<String, dynamic>? data;
    try {
      data = (await _buildingRef
              .get()
              .timeout(const Duration(seconds: 8)))
          .data();
    } catch (_) {
      // Can't verify who holds the seat right now (timeout/offline/etc) —
      // never grant admin access on a read that didn't actually complete.
      // Fail closed, not open — and never leave the caller's loading
      // overlay hanging forever waiting on an await with no timeout.
      return false;
    }
    final existing = data?['adminPhone'] as String? ?? '';
    if (existing.isEmpty) {
      try {
        await _buildingRef
            .set({'adminPhone': e164Phone}, SetOptions(merge: true))
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        return false;
      }
      return true;
    }
    return _normalizedPhone(existing) == _normalizedPhone(e164Phone);
  }

  /// Hands the sole admin seat to a different phone number — including one
  /// that has never signed in yet, which is exactly why admin authority is
  /// matched by phone rather than by uid (a future uid can't be known in
  /// advance). Callers are responsible for signing the outgoing admin's
  /// session out afterward.
  Future<void> transferAdmin(String newPhone) async {
    if (_mock) {
      _building.adminPhone = newPhone.trim();
      notifyListeners();
      return;
    }
    await _buildingRef.set({
      'adminPhone': toE164Phone(newPhone.trim()),
    }, SetOptions(merge: true));
  }

  /// Updates the current admin's display name — the lightweight "edit my
  /// name" case, distinct from the full block setup form.
  Future<void> updateAdminName(String name) async {
    final trimmed = name.trim();
    if (_mock) {
      _building.adminName = trimmed;
      notifyListeners();
      return;
    }
    await _buildingRef.set({'adminName': trimmed}, SetOptions(merge: true));
  }

  Future<void> addFlat({
    required String flatNumber,
    required String residentName,
    required String phone,
    bool tankerExempt = false,
    List<CoResident>? coResidents,
  }) async {
    final existing = flatByNumber(flatNumber);
    final flat = Flat(
      flatNumber: flatNumber,
      residentName: residentName,
      phone: _mock ? phone : toE164Phone(phone),
      tankerExempt: tankerExempt,
      coResidents: (coResidents ?? [])
          .where((c) => c.phone.trim().isNotEmpty)
          .map(
            (c) => CoResident(
              name: c.name.trim(),
              // Normalized exactly like the primary number, because the
              // security rules compare these against the E.164 phone in
              // the caller's ID token — a number stored any other way
              // would silently fail to authorize its own owner.
              phone: _mock ? c.phone.trim() : toE164Phone(c.phone),
            ),
          )
          .toList(),
      // Editing a flat must not wipe what residents have already accrued;
      // this method doubles as the edit path (it overwrites the document).
      openingBalancePaise: existing?.openingBalancePaise ?? 0,
      passwordSet: existing?.passwordSet ?? false,
    );
    if (_mock) {
      _flats.removeWhere((f) => f.flatNumber == flatNumber);
      _flats.add(flat);
      notifyListeners();
      return;
    }
    // Merged rather than replaced: a plain set() would drop fcmToken and
    // fcmTokens, which live on this document but are written only by the
    // push service and are not part of the Flat model.
    await _flatsRef.doc(flatNumber).set(flat.toMap(), SetOptions(merge: true));
  }

  /// Removes a flat and the bills raised against it.
  ///
  /// The bills go with it deliberately: a bill whose flat no longer exists
  /// still counts toward collection totals and still appears in the month's
  /// figures, with nothing to attribute it to. Anyone signed in for that
  /// flat loses access at the same time, since every rule resolves through
  /// the flat document.
  Future<void> deleteFlat(String flatNumber) async {
    if (_mock) {
      _flats.removeWhere((f) => f.flatNumber == flatNumber);
      _currentMonth.bills.removeWhere((b) => b.flatNumber == flatNumber);
      notifyListeners();
      return;
    }
    final batch = _firestore.batch();
    batch.delete(_flatsRef.doc(flatNumber));
    // Only this month's bill: earlier months are settled history, and
    // rewriting them would change totals residents have already been shown.
    batch.delete(_billsRef.doc(flatNumber));
    await batch.commit();
  }

  Future<void> joinAssociation(String code) async {
    final assoc = Association(
      code: code,
      name: 'Shilpa Pine Valley',
      buildingCount: 20,
      joined: true,
    );
    if (_mock) {
      _association = assoc;
      notifyListeners();
      return;
    }
    await _buildingRef.set({
      'association': assoc.toMap(),
    }, SetOptions(merge: true));
  }

  Future<void> leaveAssociation() async {
    final assoc = Association();
    if (_mock) {
      _association = assoc;
      notifyListeners();
      return;
    }
    await _buildingRef.set({
      'association': assoc.toMap(),
    }, SetOptions(merge: true));
  }

  // ── Mutations: expenses & advances ──────────────────────────────────

  /// How much [expense] currently draws from the reserve fund — 0 unless
  /// it's actually marked [Expense.fundedByReserve]. Used to work out the
  /// net change to [Building.reserveFundPaise] on add/edit/delete, since an
  /// edit can flip an expense in or out of reserve funding, not just
  /// change its amount.
  int _reserveContributionOf(Expense? expense) =>
      (expense != null && expense.fundedByReserve) ? expense.amountPaise : 0;

  /// Shared add/update path — the only difference between creating a new
  /// expense and editing one is what [previous] contributed to the reserve
  /// fund (0 for a brand-new expense). Returns false, writing nothing, if
  /// this would draw the reserve fund below zero — spending must never
  /// silently go negative the way [addReserveContributions] cannot fail.
  Future<bool> _saveExpense(Expense expense, {Expense? previous}) async {
    final delta = _reserveContributionOf(expense) - _reserveContributionOf(previous);
    if (delta > 0 && delta > _building.reserveFundPaise) return false;

    if (_mock) {
      _building.reserveFundPaise -= delta;
      if (previous == null) {
        _currentMonth.expenses.add(expense);
      } else {
        final idx = _currentMonth.expenses.indexWhere((e) => e.id == expense.id);
        if (idx != -1) _currentMonth.expenses[idx] = expense;
      }
      notifyListeners();
      return true;
    }

    final batch = _firestore.batch();
    batch.set(_expensesRef.doc(expense.id), expense.toMap());
    if (delta != 0) {
      batch.set(_buildingRef, {
        'reserveFundPaise': _building.reserveFundPaise - delta,
      }, SetOptions(merge: true));
    }
    await batch.commit();
    return true;
  }

  Future<bool> addExpense(Expense expense) => _saveExpense(expense);

  Future<bool> updateExpense(Expense expense) {
    final previous = _currentMonth.expenses
        .where((e) => e.id == expense.id)
        .firstOrNull;
    return _saveExpense(expense, previous: previous);
  }

  Future<void> deleteExpense(String expenseId) async {
    final existing = _currentMonth.expenses
        .where((e) => e.id == expenseId)
        .firstOrNull;
    final refund = _reserveContributionOf(existing);

    if (_mock) {
      _building.reserveFundPaise += refund;
      _currentMonth.expenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();
      return;
    }

    final batch = _firestore.batch();
    batch.delete(_expensesRef.doc(expenseId));
    if (refund != 0) {
      batch.set(_buildingRef, {
        'reserveFundPaise': _building.reserveFundPaise + refund,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Records [perFlatPaise] collected from each of [flatNumbers] into the
  /// reserve fund: one contribution record per flat, plus the matching
  /// increase to the running balance, written together so the balance can
  /// never disagree with the records behind it.
  ///
  /// Per flat rather than a lump sum because residents pay at their own
  /// pace — the admin needs to see who is still outstanding, which a
  /// single total can't answer. Additive to whatever balance remains,
  /// never a replace. Unlike spending, this can't fail: there's no upper
  /// bound to validate against.
  Future<void> addReserveContributions({
    required List<String> flatNumbers,
    required int perFlatPaise,
  }) async {
    if (flatNumbers.isEmpty || perFlatPaise <= 0) return;
    final now = DateTime.now();
    final records = flatNumbers.map((flatNumber) {
      return ReserveContribution(
        id: '${now.millisecondsSinceEpoch}_$flatNumber',
        flatNumber: flatNumber,
        residentName: flatByNumber(flatNumber)?.residentName ?? '',
        amountPaise: perFlatPaise,
        collectedOn: now,
      );
    }).toList();
    final total = perFlatPaise * records.length;

    if (_mock) {
      _reserveContributions.insertAll(0, records);
      _building.reserveFundPaise += total;
      notifyListeners();
      return;
    }

    final batch = _firestore.batch();
    for (final r in records) {
      batch.set(_reserveContributionsRef.doc(r.id), r.toMap());
    }
    batch.set(_buildingRef, {
      'reserveFundPaise': _building.reserveFundPaise + total,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Removes a contribution recorded by mistake and takes its amount back
  /// out of the balance, so deleting the record and correcting the total
  /// are never two separate things the admin has to remember to do.
  Future<void> deleteReserveContribution(String id) async {
    final record = _reserveContributions.firstWhere(
      (c) => c.id == id,
      orElse: () => ReserveContribution(
        id: '',
        flatNumber: '',
        residentName: '',
        amountPaise: 0,
      ),
    );
    if (record.id.isEmpty) return;

    if (_mock) {
      _reserveContributions.removeWhere((c) => c.id == id);
      _building.reserveFundPaise -= record.amountPaise;
      notifyListeners();
      return;
    }

    final batch = _firestore.batch();
    batch.delete(_reserveContributionsRef.doc(id));
    batch.set(_buildingRef, {
      // Clamped at zero: the balance is also drawn down by reserve-funded
      // expenses, so removing an old contribution can legitimately exceed
      // what's left, and a negative reserve would be meaningless.
      'reserveFundPaise':
          (_building.reserveFundPaise - record.amountPaise).clamp(0, 1 << 62),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Recording an advance applies each recovery straight to the named
  /// flat's [Flat.openingBalancePaise] — that's how it flows into a future
  /// bill, via the normal carry-forward mechanism, per the canonical
  /// formula (no separate "advance" term on [Bill]).
  Future<void> addAdvance(Advance advance) async {
    if (_mock) {
      _currentMonth.advances.add(advance);
      for (final recovery in advance.recoveries) {
        final flat = flatByNumber(recovery.flatNumber);
        if (flat != null) {
          flat.openingBalancePaise += recovery.amountPaise;
        }
      }
      notifyListeners();
      return;
    }
    final batch = _firestore.batch();
    batch.set(_advancesRef.doc(advance.id), advance.toMap());
    for (final recovery in advance.recoveries) {
      final flat = flatByNumber(recovery.flatNumber);
      if (flat != null) {
        batch.update(_flatsRef.doc(recovery.flatNumber), {
          'openingBalancePaise': flat.openingBalancePaise + recovery.amountPaise,
        });
      }
    }
    await batch.commit();
  }

  // ── Mutations: water calculator ─────────────────────────────────────
  Future<void> updateTankerConfig({
    int? tankerCount,
    int? pricePerTankerPaise,
  }) async {
    if (tankerCount != null) _currentMonth.water.tankerCount = tankerCount;
    if (pricePerTankerPaise != null) {
      _currentMonth.water.pricePerTankerPaise = pricePerTankerPaise;
    }
    if (_mock) {
      notifyListeners();
      return;
    }
    await _currentMonthRef.set({
      'water': _currentMonth.water.toMap(),
    }, SetOptions(merge: true));
  }

  Future<void> updateReading(
    String flatNumber, {
    int? initialLitres,
    int? finalLitres,
    String? meterPhotoUrl,
  }) async {
    var reading = _currentMonth.readingFor(flatNumber);
    final isNew = reading == null;
    reading ??= MeterReading(flatNumber: flatNumber);
    if (initialLitres != null) reading.initialLitres = initialLitres;
    if (finalLitres != null) reading.finalLitres = finalLitres;
    if (meterPhotoUrl != null) reading.meterPhotoUrl = meterPhotoUrl;
    if (_mock) {
      if (isNew) _currentMonth.readings.add(reading);
      notifyListeners();
      return;
    }
    await _readingsRef.doc(flatNumber).set(reading.toMap());
  }

  // ── Mutations: billing month ─────────────────────────────────────────
  /// Sets which calendar month the current billing cycle is for — drives
  /// every "month expenses" / "maintenance bill" line in the WhatsApp/SMS
  /// messages that used to quote a hardcoded seed month. Can be changed at
  /// any time, even after bills are generated — note that already-generated
  /// bills keep the month id they were frozen with, so relabeling after
  /// generation won't retroactively rename bills already sent out.
  Future<void> setCurrentMonth(int year, int month) async {
    final id = '$year-${month.toString().padLeft(2, '0')}';
    final label = '${monthNames[month - 1]} $year';

    // Water meters are cumulative, not reset each month — last month's
    // final reading is next month's real starting point, so carry it
    // forward automatically instead of making the admin retype it. Only
    // seeds a flat that doesn't already have a reading recorded for the
    // target month, so re-selecting an already-in-progress month (this can
    // be changed at any time, per the doc above) never clobbers real data.
    final previousFinals = {
      for (final r in _currentMonth.readings) r.flatNumber: r.finalLitres,
    };

    if (_mock) {
      _currentMonth.id = id;
      _currentMonth.label = label;
      for (final flat in _flats) {
        final already = _currentMonth.readings.any(
          (r) => r.flatNumber == flat.flatNumber,
        );
        if (already) continue;
        final carried = previousFinals[flat.flatNumber] ?? 0;
        if (carried <= 0) continue;
        _currentMonth.readings.add(
          MeterReading(flatNumber: flat.flatNumber, initialLitres: carried),
        );
      }
      notifyListeners();
      return;
    }

    final targetReadingsRef = _monthsRef.doc(id).collection('readings');
    final existingSnap = await targetReadingsRef.get();
    final alreadySeeded = existingSnap.docs.map((d) => d.id).toSet();

    // The building-doc listener reacts to currentMonthId changing and
    // (re)attaches the month-level listeners itself — no need to do it here.
    final batch = _firestore.batch();
    batch.set(_monthsRef.doc(id), {
      'id': id,
      'label': label,
    }, SetOptions(merge: true));
    for (final flat in _flats) {
      if (alreadySeeded.contains(flat.flatNumber)) continue;
      final carried = previousFinals[flat.flatNumber] ?? 0;
      if (carried <= 0) continue;
      batch.set(
        targetReadingsRef.doc(flat.flatNumber),
        MeterReading(flatNumber: flat.flatNumber, initialLitres: carried).toMap(),
      );
    }
    await batch.commit();
    await _buildingRef.set({'currentMonthId': id}, SetOptions(merge: true));
  }

  static const monthNames = [
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

  // ── Mutations: bill generation & payments ───────────────────────────
  /// Freezes this month's bills from the current draft numbers. Safe to
  /// call more than once (e.g. after adjusting the water calculator) —
  /// it refreshes the financial fields on any bill that already exists
  /// rather than replacing it outright, so an in-progress payment
  /// (screenshot uploaded / confirmed) is never silently wiped out.
  Future<void> generateBills() async {
    if (_mock) {
      for (final flat in _flats) {
        final draft = computeBillDraft(flat.flatNumber);
        final existing = _currentMonth.billFor(flat.flatNumber);
        if (existing == null) {
          _currentMonth.bills.add(draft);
        } else {
          existing.openingBalancePaise = draft.openingBalancePaise;
          existing.waterChargePaise = draft.waterChargePaise;
          existing.commonSharePaise = draft.commonSharePaise;
          existing.offsetCreditsPaise = draft.offsetCreditsPaise;
        }
      }
      _currentMonth.generated = true;
      _currentMonth.generatedAt = DateTime.now();
      _currentMonth.flatCountAtGeneration = _flats.length;
      _currentMonth.frozenTotalUsageLitres = waterCalc.totalUsageLitres;
      _currentMonth.frozenTotalTankerCostPaise = waterCalc.totalTankerCostPaise;
      notifyListeners();
      return;
    }

    final batch = _firestore.batch();
    for (final flat in _flats) {
      final draft = computeBillDraft(flat.flatNumber);
      final existing = _currentMonth.billFor(flat.flatNumber);
      final merged = existing == null
          ? draft
          : (existing
              ..openingBalancePaise = draft.openingBalancePaise
              ..waterChargePaise = draft.waterChargePaise
              ..commonSharePaise = draft.commonSharePaise
              ..offsetCreditsPaise = draft.offsetCreditsPaise);
      batch.set(_billsRef.doc(flat.flatNumber), merged.toMap());
    }
    batch.set(_currentMonthRef, {
      'generated': true,
      'generatedAt': DateTime.now().millisecondsSinceEpoch,
      'flatCountAtGeneration': _flats.length,
      'frozenTotalUsageLitres': waterCalc.totalUsageLitres,
      'frozenTotalTankerCostPaise': waterCalc.totalTankerCostPaise,
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Finds this month's bill for a flat, creating it from the live draft
  /// first if [generateBills] hasn't run yet — so payment actions work
  /// even before the admin has explicitly generated bills. Mock mode only;
  /// real mode's payment methods build the same fallback inline since they
  /// need it as a plain value to merge into a Firestore write, not a
  /// reference to mutate.
  Bill _billOrDraft(String flatNumber) {
    final existing = _currentMonth.billFor(flatNumber);
    if (existing != null) return existing;
    final draft = computeBillDraft(flatNumber);
    _currentMonth.bills.add(draft);
    return draft;
  }

  Future<void> submitPaymentScreenshot(
    String flatNumber, {
    String? screenshotUrl,
  }) async {
    final now = DateTime.now();
    if (_mock) {
      final bill = _billOrDraft(flatNumber);
      bill.screenshotAdded = true;
      bill.paymentScreenshotUrl = screenshotUrl;
      bill.status = BillStatus.screenshotUploaded;
      bill.screenshotSubmittedAt = now;
      notifyListeners();
      return;
    }
    final bill = _currentMonth.billFor(flatNumber) ?? computeBillDraft(flatNumber)
      ..screenshotAdded = true
      ..paymentScreenshotUrl = screenshotUrl
      ..status = BillStatus.screenshotUploaded
      ..screenshotSubmittedAt = now;
    await _billsRef.doc(flatNumber).set(bill.toMap(), SetOptions(merge: true));
  }

  Future<void> confirmPayment(String flatNumber) async {
    final now = DateTime.now();
    if (_mock) {
      final bill = _billOrDraft(flatNumber);
      bill.status = BillStatus.confirmed;
      bill.confirmedAt = now;
      notifyListeners();
      return;
    }
    final bill = _currentMonth.billFor(flatNumber) ?? computeBillDraft(flatNumber)
      ..status = BillStatus.confirmed
      ..confirmedAt = now;
    await _billsRef.doc(flatNumber).set(bill.toMap(), SetOptions(merge: true));
  }

  // ── Mutations: issues ────────────────────────────────────────────────
  Future<void> addIssue({
    required String title,
    required String type,
    required String location,
    required String flatNumber,
    bool photoAdded = false,
    String? photoUrl,
  }) async {
    final issue = IssueReport(
      id: 'issue${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      type: type,
      location: location,
      flatNumber: flatNumber,
      photoAdded: photoAdded,
      photoUrl: photoUrl,
    );
    if (_mock) {
      _issues.insert(0, issue);
      notifyListeners();
      return;
    }
    await _issuesRef.doc(issue.id).set(issue.toMap());
  }

  Future<void> resolveIssue(String id) async {
    if (_mock) {
      for (final issue in _issues) {
        if (issue.id == id) {
          issue.status = IssueStatus.resolved;
          notifyListeners();
          return;
        }
      }
      return;
    }
    await _issuesRef.doc(id).update({'status': IssueStatus.resolved.name});
  }

  // ── Mutations: work list ─────────────────────────────────────────────
  /// The admin's own private checklist — never shown to residents.
  Future<void> addWorkItem({
    required String title,
    String description = '',
  }) async {
    final item = WorkItem(
      id: 'work${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      description: description,
    );
    if (_mock) {
      _workItems.insert(0, item);
      notifyListeners();
      return;
    }
    await _workItemsRef.doc(item.id).set(item.toMap());
  }

  Future<void> toggleWorkItem(String id) async {
    final item = _workItems.where((w) => w.id == id).firstOrNull;
    if (item == null) return;
    final isDone = !item.isDone;
    final completedAt = isDone ? DateTime.now() : null;

    if (_mock) {
      item.isDone = isDone;
      item.completedAt = completedAt;
      notifyListeners();
      return;
    }
    await _workItemsRef.doc(id).update({
      'isDone': isDone,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    });
  }

  Future<void> deleteWorkItem(String id) async {
    if (_mock) {
      _workItems.removeWhere((w) => w.id == id);
      notifyListeners();
      return;
    }
    await _workItemsRef.doc(id).delete();
  }

  // ── Mutations: community ─────────────────────────────────────────────
  Future<void> addPost({required String title, required String body}) async {
    final post = CommunityPost(
      id: 'post${DateTime.now().microsecondsSinceEpoch}',
      authorName: _building.adminName.isEmpty ? 'Admin' : _building.adminName,
      title: title,
      body: body,
    );
    if (_mock) {
      _posts.insert(0, post);
      notifyListeners();
      return;
    }
    await _postsRef.doc(post.id).set(post.toMap());
  }

  Future<void> addComment(String postId, String authorName, String text) async {
    if (_mock) {
      for (final p in _posts) {
        if (p.id == postId) {
          p.comments.add(Comment(authorName: authorName, text: text));
          notifyListeners();
          return;
        }
      }
      return;
    }
    final post = _posts.where((p) => p.id == postId).firstOrNull;
    if (post == null) return;
    final updatedComments = [
      ...post.comments,
      Comment(authorName: authorName, text: text),
    ];
    await _postsRef.doc(postId).update({
      'comments': updatedComments.map((c) => c.toMap()).toList(),
    });
  }

  Future<void> likePost(String postId) async {
    if (_mock) {
      for (final p in _posts) {
        if (p.id == postId) {
          p.likeCount += 1;
          notifyListeners();
          return;
        }
      }
      return;
    }
    await _postsRef.doc(postId).update({'likeCount': FieldValue.increment(1)});
  }
}
