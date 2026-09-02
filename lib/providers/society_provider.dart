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
import '../models/water_month.dart';
import '../utils/phone.dart';

/// Owns the whole dataset for the single building this app manages: the
/// building itself, its flats, the association it may have joined, the
/// community feed, issue reports, and the current billing month (expenses,
/// advances, water readings, generated bills).
///
/// Backed by Firestore: `buildings/main` plus its `flats`, `issues`, `posts`,
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
      _currentMonth = MonthData(id: '', label: ''),
      _pastMonths = [] {
    _watchAuthState();
  }

  SocietyProvider.mock()
    : _mock = true,
      _building = MockSeed.building(),
      _flats = MockSeed.flats(),
      _association = MockSeed.association(),
      _posts = MockSeed.communityPosts(),
      _issues = MockSeed.issues(),
      _currentMonth = MockSeed.currentMonth(),
      _pastMonths = MockSeed.pastMonths();

  final bool _mock;
  static const String _buildingDocId = 'main';

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore =>
      _firestoreInstance ??= FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _buildingRef =>
      _firestore.collection('buildings').doc(_buildingDocId);
  CollectionReference<Map<String, dynamic>> get _flatsRef =>
      _buildingRef.collection('flats');
  CollectionReference<Map<String, dynamic>> get _issuesRef =>
      _buildingRef.collection('issues');
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
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && user.uid != _attachedUid) {
        _attachedUid = user.uid;
        _detachTopLevelListeners();
        _attachTopLevelListeners();
      } else if (user == null && _attachedUid != null) {
        _attachedUid = null;
        _detachTopLevelListeners();
      }
    });
  }

  void _detachTopLevelListeners() {
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
        _posts = snap.docs.map((d) => CommunityPost.fromMap(d.data())).toList();
        notifyListeners();
      }, onError: (Object e) => debugPrint('SocietyProvider posts listener: $e')),
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
    final snap = await _monthsRef.orderBy('id', descending: true).get();
    final result = <MonthData>[];
    for (final doc in snap.docs) {
      if (doc.id == _currentMonth.id) continue;
      final month = MonthData.fromMap(doc.data());
      final billsSnap = await doc.reference.collection('bills').get();
      month.bills = billsSnap.docs.map((b) => Bill.fromMap(b.data())).toList();
      result.add(month);
    }
    _pastMonths = result;
    notifyListeners();
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
  MonthData _currentMonth;
  List<MonthData> _pastMonths;

  // ── Read access ──────────────────────────────────────────────────────
  Building get building => _building;
  List<Flat> get flats => List.unmodifiable(_flats);
  Association get association => _association;
  List<CommunityPost> get posts => List.unmodifiable(_posts);
  List<IssueReport> get issues => List.unmodifiable(_issues);
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
    final snap = await _flatsRef
        .where('phone', isEqualTo: toE164Phone(phone))
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Flat.fromMap(snap.docs.first.data());
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

    final doc = await _flatsRef.doc(flatNumber.trim()).get();
    if (!doc.exists) return 'flatNotFound';
    final flat = Flat.fromMap(doc.data()!);
    if (_normalizedPhone(toE164Phone(flat.phone)) !=
        _normalizedPhone(toE164Phone(phone))) {
      return 'flatPhoneMismatch';
    }
    await doc.reference.update({
      'residentName': name.trim(),
      'phone': toE164Phone(phone.trim()),
      'passwordSet': true,
    });
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
      if (_normalizedPhone(flat.phone) != _normalizedPhone(phone)) {
        return 'flatPhoneMismatch';
      }
      return null;
    }
    final doc = await _flatsRef.doc(flatNumber.trim()).get();
    if (!doc.exists) return 'flatNotFound';
    final flat = Flat.fromMap(doc.data()!);
    if (_normalizedPhone(toE164Phone(flat.phone)) !=
        _normalizedPhone(toE164Phone(phone))) {
      return 'flatPhoneMismatch';
    }
    return null;
  }

  String _normalizedPhone(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Whether [phone] is allowed to hold the admin seat — true if no admin
  /// is bound yet (first to log in as admin claims it) or if it matches
  /// the already-bound admin. There is only ever one admin per building;
  /// the Firestore rules enforce this same phone match server-side.
  bool canSignInAsAdmin(String phone) {
    if (_building.adminPhone.isEmpty) return true;
    return _normalizedPhone(toE164Phone(_building.adminPhone)) ==
        _normalizedPhone(toE164Phone(phone));
  }

  /// Binds [phone] as the admin if the seat is still unclaimed. No-ops if
  /// an admin is already bound — reassignment only happens via
  /// [transferAdmin]. Stored in E.164 form so it matches the phone number
  /// Firebase Auth puts in the ID token for the security rules.
  Future<void> claimAdminIfUnbound(String phone) async {
    if (_building.adminPhone.isNotEmpty || phone.trim().isEmpty) return;
    if (_mock) {
      _building.adminPhone = phone.trim();
      notifyListeners();
      return;
    }
    await _buildingRef.set({
      'adminPhone': toE164Phone(phone.trim()),
    }, SetOptions(merge: true));
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
  }) async {
    final flat = Flat(
      flatNumber: flatNumber,
      residentName: residentName,
      phone: _mock ? phone : toE164Phone(phone),
      tankerExempt: tankerExempt,
    );
    if (_mock) {
      _flats.removeWhere((f) => f.flatNumber == flatNumber);
      _flats.add(flat);
      notifyListeners();
      return;
    }
    await _flatsRef.doc(flatNumber).set(flat.toMap());
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
  Future<void> addExpense(Expense expense) async {
    if (_mock) {
      _currentMonth.expenses.add(expense);
      notifyListeners();
      return;
    }
    await _expensesRef.doc(expense.id).set(expense.toMap());
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
  }) async {
    var reading = _currentMonth.readingFor(flatNumber);
    final isNew = reading == null;
    reading ??= MeterReading(flatNumber: flatNumber);
    if (initialLitres != null) reading.initialLitres = initialLitres;
    if (finalLitres != null) reading.finalLitres = finalLitres;
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
    if (_mock) {
      _currentMonth.id = id;
      _currentMonth.label = label;
      notifyListeners();
      return;
    }
    // The building-doc listener reacts to currentMonthId changing and
    // (re)attaches the month-level listeners itself — no need to do it here.
    await _monthsRef.doc(id).set({
      'id': id,
      'label': label,
    }, SetOptions(merge: true));
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

  // ── Mutations: community ─────────────────────────────────────────────
  Future<void> addPost({required String title, required String body}) async {
    final post = CommunityPost(
      id: 'post${DateTime.now().microsecondsSinceEpoch}',
      authorName: _building.adminName.isEmpty ? 'Admin' : _building.adminName,
      timeLabel: 'Just now',
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
