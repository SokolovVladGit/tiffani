import '../entities/discount_campaign_entity.dart';

abstract interface class AdminDiscountsRepository {
  /// Lists campaigns of [kind], active first, then by `created_at desc`.
  /// For automatic kinds, related targets are loaded inline.
  Future<List<DiscountCampaignEntity>> listCampaigns(
    DiscountCampaignKind kind,
  );

  /// Inserts or updates a campaign (and, for automatic, replaces targets
  /// in a delete-then-insert cycle). Returns the persisted entity with
  /// the assigned `id` and refreshed `usedCount`/`updated_at`-like fields.
  Future<DiscountCampaignEntity> upsertCampaign(
    DiscountCampaignEntity campaign,
  );

  /// Toggles `is_active` on a campaign without touching any other field.
  Future<DiscountCampaignEntity> setActive({
    required String campaignId,
    required bool isActive,
  });
}
