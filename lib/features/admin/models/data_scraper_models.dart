/// Pipeline models for the scraping pipeline.
library;

enum PipelineStatus { idle, scanning, processing, complete, error }

enum PipelineStep { scrape, ingest, detect, resolve, enrich, metrics }

class ScanResult {
  const ScanResult({
    required this.postsReceived,
    required this.newPosts,
    required this.restaurantCandidates,
    required this.newRestaurants,
    required this.verifiedRestaurants,
    required this.costUsd,
  });

  final int postsReceived;
  final int newPosts;
  final int restaurantCandidates;
  final int newRestaurants;
  final int verifiedRestaurants;
  final double costUsd;

  Map<String, dynamic> toJson() => {
    'postsReceived': postsReceived,
    'newPosts': newPosts,
    'restaurantCandidates': restaurantCandidates,
    'newRestaurants': newRestaurants,
    'verifiedRestaurants': verifiedRestaurants,
    'costUsd': costUsd,
  };

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
    postsReceived: json['postsReceived'] as int? ?? 0,
    newPosts: json['newPosts'] as int? ?? 0,
    restaurantCandidates: json['restaurantCandidates'] as int? ?? 0,
    newRestaurants: json['newRestaurants'] as int? ?? 0,
    verifiedRestaurants: json['verifiedRestaurants'] as int? ?? 0,
    costUsd: (json['costUsd'] as num?)?.toDouble() ?? 0,
  );
}

class DiscoverySourceSummary {
  const DiscoverySourceSummary({
    required this.id,
    required this.sourceType,
    required this.sourceValue,
    required this.area,
    required this.status,
    required this.postsScraped,
    required this.newRestaurants,
    required this.yieldRate,
    required this.totalCostUsd,
    required this.costPerNewRestaurant,
    required this.priorityScore,
    this.lastScrapedAt,
    this.createdAt,
  });

  final int id;
  final String sourceType;
  final String sourceValue;
  final String? area;
  final String status;
  final int postsScraped;
  final int newRestaurants;
  final double yieldRate;
  final double totalCostUsd;
  final double? costPerNewRestaurant;
  final double priorityScore;
  final DateTime? lastScrapedAt;
  final DateTime? createdAt;

  factory DiscoverySourceSummary.fromMap(Map<String, dynamic> m) =>
    DiscoverySourceSummary(
      id: m['id'] as int,
      sourceType: m['source_type'] as String? ?? 'unknown',
      sourceValue: m['source_value'] as String? ?? '',
      area: m['area'] as String?,
      status: m['status'] as String? ?? 'active',
      postsScraped: m['posts_scraped'] as int? ?? 0,
      newRestaurants: m['new_restaurants'] as int? ?? 0,
      yieldRate: (m['yield_rate'] as num?)?.toDouble() ?? 0,
      totalCostUsd: (m['total_cost_usd'] as num?)?.toDouble() ?? 0,
      costPerNewRestaurant: (m['cost_per_new_restaurant'] as num?)?.toDouble(),
      priorityScore: (m['priority_score'] as num?)?.toDouble() ?? 0.5,
      lastScrapedAt: m['last_scraped_at'] != null
          ? DateTime.tryParse(m['last_scraped_at'] as String)
          : null,
      createdAt: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'] as String)
          : null,
    );
}

class ScrapeRunSummary {
  const ScrapeRunSummary({
    required this.id,
    required this.status,
    required this.postsReceived,
    required this.newPosts,
    required this.newRestaurants,
    required this.costUsd,
    this.startedAt,
    this.completedAt,
    this.error,
  });

  final String id;
  final String status;
  final int postsReceived;
  final int newPosts;
  final int newRestaurants;
  final double costUsd;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? error;

  factory ScrapeRunSummary.fromMap(Map<String, dynamic> m) =>
    ScrapeRunSummary(
      id: m['id'] as String,
      status: m['status'] as String? ?? 'pending',
      postsReceived: m['posts_received'] as int? ?? 0,
      newPosts: m['new_posts'] as int? ?? 0,
      newRestaurants: m['new_restaurants'] as int? ?? 0,
      costUsd: (m['cost_usd'] as num?)?.toDouble() ?? 0,
      startedAt: m['started_at'] != null
          ? DateTime.tryParse(m['started_at'] as String)
          : null,
      completedAt: m['completed_at'] != null
          ? DateTime.tryParse(m['completed_at'] as String)
          : null,
      error: m['error'] as String?,
    );
}

class PipelineState {
  const PipelineState({
    this.status = PipelineStatus.idle,
    this.currentStep,
    this.stepMessage = '',
    this.initMessage = '',
    this.result,
    this.lastScanTime,
    this.totalRestaurants = 0,
    this.totalPosts = 0,
    this.totalCostUsd = 0,
    this.error,
    this.activeRunId,
    this.activeJobId,
    this.resultLimit = 1,
    this.persistedResult,
    this.persistedScanTime,
    this.discoverySources = const [],
    this.recentRuns = const [],
  });

  final PipelineStatus status;
  final PipelineStep? currentStep;
  final String stepMessage;
  final String initMessage;
  final ScanResult? result;
  final DateTime? lastScanTime;
  final int totalRestaurants;
  final int totalPosts;
  final double totalCostUsd;
  final String? error;
  final String? activeRunId;
  final String? activeJobId;
  final int resultLimit;
  final ScanResult? persistedResult;
  final DateTime? persistedScanTime;
  final List<DiscoverySourceSummary> discoverySources;
  final List<ScrapeRunSummary> recentRuns;

  PipelineState copyWith({
    PipelineStatus? status,
    PipelineStep? currentStep,
    String? stepMessage,
    String? initMessage,
    ScanResult? result,
    DateTime? lastScanTime,
    int? totalRestaurants,
    int? totalPosts,
    double? totalCostUsd,
    String? error,
    String? activeRunId,
    String? activeJobId,
    int? resultLimit,
    ScanResult? persistedResult,
    DateTime? persistedScanTime,
    List<DiscoverySourceSummary>? discoverySources,
    List<ScrapeRunSummary>? recentRuns,
  }) {
    return PipelineState(
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      stepMessage: stepMessage ?? this.stepMessage,
      initMessage: initMessage ?? this.initMessage,
      result: result ?? this.result,
      lastScanTime: lastScanTime ?? this.lastScanTime,
      totalRestaurants: totalRestaurants ?? this.totalRestaurants,
      totalPosts: totalPosts ?? this.totalPosts,
      totalCostUsd: totalCostUsd ?? this.totalCostUsd,
      error: error ?? this.error,
      activeRunId: activeRunId ?? this.activeRunId,
      activeJobId: activeJobId ?? this.activeJobId,
      resultLimit: resultLimit ?? this.resultLimit,
      persistedResult: persistedResult ?? this.persistedResult,
      persistedScanTime: persistedScanTime ?? this.persistedScanTime,
      discoverySources: discoverySources ?? this.discoverySources,
      recentRuns: recentRuns ?? this.recentRuns,
    );
  }
}
