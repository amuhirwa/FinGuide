/*
 * SMS Consent BLoC
 * ================
 * Manages the SMS consent flow:  consent → permission → historical import → listening.
 */

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/services/sms_service.dart';
import '../../../auth/data/datasources/auth_local_datasource.dart';

// ─── Events ──────────────────────────────────────────────────────────

abstract class SmsConsentEvent extends Equatable {
  const SmsConsentEvent();

  @override
  List<Object?> get props => [];
}

/// User tapped "Allow" on the consent screen.
class SmsConsentAccepted extends SmsConsentEvent {}

/// User tapped "Not Now" / declined.
class SmsConsentDeclined extends SmsConsentEvent {}

// ─── States ──────────────────────────────────────────────────────────

abstract class SmsConsentState extends Equatable {
  const SmsConsentState();

  @override
  List<Object?> get props => [];
}

/// Initial — showing the consent form.
class SmsConsentInitial extends SmsConsentState {}

/// Requesting OS-level SMS permission.
class SmsConsentRequestingPermission extends SmsConsentState {}

/// Permission was denied by the OS.
class SmsConsentPermissionDenied extends SmsConsentState {}

/// Permission granted — now importing historical messages.
class SmsConsentImporting extends SmsConsentState {}

/// Import complete — ready to navigate away.
class SmsConsentComplete extends SmsConsentState {
  final int transactionsImported;

  const SmsConsentComplete({required this.transactionsImported});

  @override
  List<Object?> get props => [transactionsImported];
}

/// User declined consent — skip the import.
class SmsConsentSkipped extends SmsConsentState {}

/// Something went wrong during import.
class SmsConsentError extends SmsConsentState {
  final String message;

  const SmsConsentError(this.message);

  @override
  List<Object?> get props => [message];
}

// ─── BLoC ────────────────────────────────────────────────────────────

class SmsConsentBloc extends Bloc<SmsConsentEvent, SmsConsentState> {
  final SmsService _smsService;
  final AuthLocalDataSource _localDataSource;

  SmsConsentBloc({
    required SmsService smsService,
    required AuthLocalDataSource localDataSource,
  })  : _smsService = smsService,
        _localDataSource = localDataSource,
        super(SmsConsentInitial()) {
    on<SmsConsentAccepted>(_onAccepted);
    on<SmsConsentDeclined>(_onDeclined);
  }

  Future<void> _onAccepted(
    SmsConsentAccepted event,
    Emitter<SmsConsentState> emit,
  ) async {
    // 1. Request OS permission
    emit(SmsConsentRequestingPermission());

    final granted = await _smsService.requestPermission();
    if (!granted) {
      emit(SmsConsentPermissionDenied());
      return;
    }

    // 2. Persist consent
    await _smsService.setConsent(true);

    // 3. Import historical messages
    emit(SmsConsentImporting());

    try {
      final count = await _smsService.importHistoricalMessages();

      // 4. Start real-time listener
      _smsService.startListening();

      // 5. Mark consent flow as completed
      await _localDataSource.setSmsConsentCompleted();

      emit(SmsConsentComplete(transactionsImported: count));
    } catch (e) {
      emit(SmsConsentError(e.toString()));
    }
  }

  Future<void> _onDeclined(
    SmsConsentDeclined event,
    Emitter<SmsConsentState> emit,
  ) async {
    await _smsService.setConsent(false);
    await _localDataSource.setSmsConsentCompleted();
    emit(SmsConsentSkipped());
  }
}
