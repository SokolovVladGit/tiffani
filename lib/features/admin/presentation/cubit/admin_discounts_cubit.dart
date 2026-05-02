import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/discount_campaign_entity.dart';
import '../../domain/repositories/admin_discounts_repository.dart';
import 'admin_discounts_state.dart';

/// State holder for the admin discount panel.
///
/// One cubit instance backs both tabs (Промокоды / Скидки) so the panel can
/// switch between them without re-fetching unless explicitly requested. Each
/// list maintains its own status, list payload, and error string.
class AdminDiscountsCubit extends Cubit<AdminDiscountsState> {
  final AdminDiscountsRepository _repository;

  AdminDiscountsCubit(this._repository) : super(const AdminDiscountsState());

  Future<void> loadPromocodes({bool force = false}) async {
    if (!force &&
        state.promocodesStatus == AdminListStatus.loading) {
      return;
    }
    emit(state.copyWith(
      promocodesStatus: AdminListStatus.loading,
      clearPromocodesError: true,
    ));
    try {
      final list =
          await _repository.listCampaigns(DiscountCampaignKind.promocode);
      emit(state.copyWith(
        promocodesStatus: AdminListStatus.loaded,
        promocodes: list,
        clearPromocodesError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        promocodesStatus: AdminListStatus.error,
        promocodesError: _friendlyError(e),
      ));
    }
  }

  Future<void> loadAutomatics({bool force = false}) async {
    if (!force &&
        state.automaticsStatus == AdminListStatus.loading) {
      return;
    }
    emit(state.copyWith(
      automaticsStatus: AdminListStatus.loading,
      clearAutomaticsError: true,
    ));
    try {
      final list =
          await _repository.listCampaigns(DiscountCampaignKind.automatic);
      emit(state.copyWith(
        automaticsStatus: AdminListStatus.loaded,
        automatics: list,
        clearAutomaticsError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        automaticsStatus: AdminListStatus.error,
        automaticsError: _friendlyError(e),
      ));
    }
  }

  /// Returns the persisted entity on success and `null` on failure
  /// (with a Russian error string supplied via [onError]).
  Future<DiscountCampaignEntity?> saveCampaign(
    DiscountCampaignEntity campaign, {
    void Function(String message)? onError,
  }) async {
    final id = campaign.id;
    final mutating = Set<String>.from(state.mutatingIds);
    if (id != null) mutating.add(id);
    emit(state.copyWith(
      mutatingIds: mutating,
      isCreating: id == null ? true : state.isCreating,
    ));

    try {
      final saved = await _repository.upsertCampaign(campaign);
      _replaceInCorrectList(saved);
      return saved;
    } catch (e) {
      onError?.call(_friendlyError(e));
      return null;
    } finally {
      final cleaned = Set<String>.from(state.mutatingIds);
      if (id != null) cleaned.remove(id);
      emit(state.copyWith(
        mutatingIds: cleaned,
        isCreating: id == null ? false : state.isCreating,
      ));
    }
  }

  Future<void> setActive(
    DiscountCampaignEntity campaign,
    bool isActive, {
    void Function(String message)? onError,
  }) async {
    final id = campaign.id;
    if (id == null) return;
    final mutating = Set<String>.from(state.mutatingIds)..add(id);
    emit(state.copyWith(mutatingIds: mutating));

    try {
      final updated =
          await _repository.setActive(campaignId: id, isActive: isActive);
      _replaceInCorrectList(updated);
    } catch (e) {
      onError?.call(_friendlyError(e));
    } finally {
      final cleaned = Set<String>.from(state.mutatingIds)..remove(id);
      emit(state.copyWith(mutatingIds: cleaned));
    }
  }

  void _replaceInCorrectList(DiscountCampaignEntity entity) {
    if (entity.kind == DiscountCampaignKind.promocode) {
      final list = _replaceOrPrepend(state.promocodes, entity);
      emit(state.copyWith(
        promocodes: _sortCampaigns(list),
        promocodesStatus: AdminListStatus.loaded,
      ));
    } else {
      final list = _replaceOrPrepend(state.automatics, entity);
      emit(state.copyWith(
        automatics: _sortCampaigns(list),
        automaticsStatus: AdminListStatus.loaded,
      ));
    }
  }

  static List<DiscountCampaignEntity> _replaceOrPrepend(
    List<DiscountCampaignEntity> existing,
    DiscountCampaignEntity entity,
  ) {
    final id = entity.id;
    if (id == null) return [entity, ...existing];
    final idx = existing.indexWhere((c) => c.id == id);
    if (idx == -1) return [entity, ...existing];
    final next = List<DiscountCampaignEntity>.from(existing);
    next[idx] = entity;
    return next;
  }

  /// Active campaigns first; within each group preserve original order
  /// (server already returns by `created_at desc`, and freshly-saved items
  /// stay near the top thanks to prepend).
  static List<DiscountCampaignEntity> _sortCampaigns(
    List<DiscountCampaignEntity> list,
  ) {
    final active = <DiscountCampaignEntity>[];
    final inactive = <DiscountCampaignEntity>[];
    for (final c in list) {
      (c.isActive ? active : inactive).add(c);
    }
    return [...active, ...inactive];
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('uq_discount_campaigns_code') ||
        lower.contains('duplicate key') ||
        lower.contains('unique constraint')) {
      return 'Промокод с таким кодом уже существует';
    }
    if (lower.contains('chk_discount_campaigns_percent_off')) {
      return 'Процент скидки должен быть больше 0 и не больше 100';
    }
    if (lower.contains('chk_discount_campaigns_min_order_amount')) {
      return 'Минимальная сумма заказа не может быть отрицательной';
    }
    if (lower.contains('chk_discount_campaigns_max_redemptions')) {
      return 'Лимит использований должен быть положительным числом';
    }
    if (lower.contains('chk_discount_targets_value_presence')) {
      return 'Для выбранного типа условия требуется значение';
    }
    if (lower.contains('chk_discount_campaigns_kind')) {
      return 'Недопустимый тип кампании';
    }
    if (lower.contains('row-level security') ||
        lower.contains('permission denied')) {
      return 'Недостаточно прав для этого действия';
    }
    if (lower.contains('failedhostlookup') ||
        lower.contains('socketexception')) {
      return 'Нет соединения с сервером';
    }
    return 'Произошла ошибка. Попробуйте позже.';
  }
}
