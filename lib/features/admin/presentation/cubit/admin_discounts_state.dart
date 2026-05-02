import '../../domain/entities/discount_campaign_entity.dart';

enum AdminListStatus { idle, loading, loaded, error }

class AdminDiscountsState {
  final AdminListStatus promocodesStatus;
  final List<DiscountCampaignEntity> promocodes;
  final String? promocodesError;

  final AdminListStatus automaticsStatus;
  final List<DiscountCampaignEntity> automatics;
  final String? automaticsError;

  /// Set while a single campaign is being saved or toggled. Allows the UI
  /// to disable individual cards/forms without a full-list spinner.
  final Set<String> mutatingIds;

  /// Set true while a brand-new campaign is being inserted.
  final bool isCreating;

  const AdminDiscountsState({
    this.promocodesStatus = AdminListStatus.idle,
    this.promocodes = const [],
    this.promocodesError,
    this.automaticsStatus = AdminListStatus.idle,
    this.automatics = const [],
    this.automaticsError,
    this.mutatingIds = const {},
    this.isCreating = false,
  });

  AdminDiscountsState copyWith({
    AdminListStatus? promocodesStatus,
    List<DiscountCampaignEntity>? promocodes,
    String? promocodesError,
    AdminListStatus? automaticsStatus,
    List<DiscountCampaignEntity>? automatics,
    String? automaticsError,
    Set<String>? mutatingIds,
    bool? isCreating,
    bool clearPromocodesError = false,
    bool clearAutomaticsError = false,
  }) {
    return AdminDiscountsState(
      promocodesStatus: promocodesStatus ?? this.promocodesStatus,
      promocodes: promocodes ?? this.promocodes,
      promocodesError: clearPromocodesError
          ? null
          : (promocodesError ?? this.promocodesError),
      automaticsStatus: automaticsStatus ?? this.automaticsStatus,
      automatics: automatics ?? this.automatics,
      automaticsError: clearAutomaticsError
          ? null
          : (automaticsError ?? this.automaticsError),
      mutatingIds: mutatingIds ?? this.mutatingIds,
      isCreating: isCreating ?? this.isCreating,
    );
  }
}
