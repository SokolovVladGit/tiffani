import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../../domain/entities/discount_campaign_entity.dart';
import '../../domain/entities/discount_campaign_target_entity.dart';
import '../../domain/repositories/admin_discounts_repository.dart';
import '../dto/discount_campaign_dto.dart';
import '../dto/discount_campaign_target_dto.dart';

const _campaignsTable = 'discount_campaigns';
const _targetsTable = 'discount_campaign_targets';

class AdminDiscountsRepositoryImpl implements AdminDiscountsRepository {
  final SupabaseClient _client;
  final LoggerService _logger;

  const AdminDiscountsRepositoryImpl(this._client, this._logger);

  @override
  Future<List<DiscountCampaignEntity>> listCampaigns(
    DiscountCampaignKind kind,
  ) async {
    try {
      final rows = await _client
          .from(_campaignsTable)
          .select()
          .eq('kind', kind.wireValue)
          .order('is_active', ascending: false)
          .order('created_at', ascending: false);

      final campaignList = (rows as List).cast<Map<String, dynamic>>();
      if (campaignList.isEmpty) return const [];

      final Map<String, List<DiscountCampaignTargetEntity>> byCampaignId = {};
      if (kind == DiscountCampaignKind.automatic) {
        final ids = campaignList
            .map((r) => r['id'])
            .whereType<String>()
            .toList(growable: false);

        if (ids.isNotEmpty) {
          final tRows = await _client
              .from(_targetsTable)
              .select()
              .inFilter('campaign_id', ids);

          for (final row in (tRows as List).cast<Map<String, dynamic>>()) {
            final entity = DiscountCampaignTargetDto.parse(row);
            final cid = entity.campaignId;
            if (cid == null) continue;
            byCampaignId.putIfAbsent(cid, () => []).add(entity);
          }
        }
      }

      return campaignList.map((row) {
        final id = row['id'] as String?;
        final List<DiscountCampaignTargetEntity> targets = id != null
            ? (byCampaignId[id] ?? const <DiscountCampaignTargetEntity>[])
            : const <DiscountCampaignTargetEntity>[];
        return DiscountCampaignDto.parse(row, targets: targets);
      }).toList(growable: false);
    } catch (e, st) {
      _logger.e('listCampaigns($kind) failed: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<DiscountCampaignEntity> upsertCampaign(
    DiscountCampaignEntity campaign,
  ) async {
    try {
      final String campaignId;
      final Map<String, dynamic> savedRow;

      if (campaign.id == null) {
        final inserted = await _client
            .from(_campaignsTable)
            .insert(DiscountCampaignDto.toInsertMap(campaign))
            .select()
            .single();
        savedRow = inserted;
        campaignId = inserted['id'] as String;
      } else {
        final updated = await _client
            .from(_campaignsTable)
            .update(DiscountCampaignDto.toUpdateMap(campaign))
            .eq('id', campaign.id!)
            .select()
            .single();
        savedRow = updated;
        campaignId = campaign.id!;
      }

      List<DiscountCampaignTargetEntity> persistedTargets = const [];
      if (campaign.kind == DiscountCampaignKind.automatic) {
        await _client.from(_targetsTable).delete().eq('campaign_id', campaignId);
        if (campaign.targets.isNotEmpty) {
          final inserts = campaign.targets
              .map((t) => DiscountCampaignTargetDto.toInsertMap(
                    campaignId: campaignId,
                    target: t,
                  ))
              .toList(growable: false);
          final tRows = await _client
              .from(_targetsTable)
              .insert(inserts)
              .select();
          persistedTargets = (tRows as List)
              .cast<Map<String, dynamic>>()
              .map(DiscountCampaignTargetDto.parse)
              .toList(growable: false);
        }
      }

      return DiscountCampaignDto.parse(savedRow, targets: persistedTargets);
    } catch (e, st) {
      _logger.e('upsertCampaign(${campaign.id}) failed: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<DiscountCampaignEntity> setActive({
    required String campaignId,
    required bool isActive,
  }) async {
    try {
      final updated = await _client
          .from(_campaignsTable)
          .update({'is_active': isActive})
          .eq('id', campaignId)
          .select()
          .single();

      final kind = DiscountCampaignKind.fromWire(updated['kind'] as String?);
      List<DiscountCampaignTargetEntity> targets = const [];
      if (kind == DiscountCampaignKind.automatic) {
        final tRows = await _client
            .from(_targetsTable)
            .select()
            .eq('campaign_id', campaignId);
        targets = (tRows as List)
            .cast<Map<String, dynamic>>()
            .map(DiscountCampaignTargetDto.parse)
            .toList(growable: false);
      }
      return DiscountCampaignDto.parse(updated, targets: targets);
    } catch (e, st) {
      _logger.e('setActive($campaignId, $isActive) failed: $e\n$st');
      rethrow;
    }
  }
}
