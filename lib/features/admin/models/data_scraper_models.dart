/// Pipeline models for the scraping pipeline.
library;

enum PipelineStatus { idle, scanning, processing, complete, error }

enum PipelineStep { scrape, ingest, detect, resolve, enrich, metrics }

/// Status of an auto-run session.
enum AutoRunStatus { idle, running, paused, completed, failed, stopped }

/// Configuration for an auto-run session.
class AutoRunConfig {
  const AutoRunConfig({
    this.resultsPerQuery = 30,
    this.maxQueries = 10,
    this.costLimitUsd = 5.0,
  });

  final int resultsPerQuery;
  final int maxQueries;
  final double costLimitUsd;

  Map<String, dynamic> toJson() => {
    'results_per_query': resultsPerQuery,
    'max_queries': maxQueries,
    'cost_limit_usd': costLimitUsd,
  };

  factory AutoRunConfig.fromJson(Map<String, dynamic> json) => AutoRunConfig(
    resultsPerQuery: json['results_per_query'] as int? ?? 30,
    maxQueries: json['max_queries'] as int? ?? 10,
    costLimitUsd: (json['cost_limit_usd'] as num?)?.toDouble() ?? 5.0,
  );
}

/// State of an auto-run session.
class AutoRunState {
  const AutoRunState({
    this.id,
    this.status = AutoRunStatus.idle,
    this.config = const AutoRunConfig(),
    this.currentQuerySourceId,
    this.queriesCompleted = 0,
    this.newRestaurants = 0,
    this.existingMatched = 0,
    this.skippedNoImage = 0,
    this.failedCandidates = 0,
    this.totalCostUsd = 0,
    this.stopReason,
    this.startedAt,
    this.completedAt,
  });

  final String? id;
  final AutoRunStatus status;
  final AutoRunConfig config;
  final int? currentQuerySourceId;
  final int queriesCompleted;
  final int newRestaurants;
  final int existingMatched;
  final int skippedNoImage;
  final int failedCandidates;
  final double totalCostUsd;
  final String? stopReason;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isActive =>
      status == AutoRunStatus.running || status == AutoRunStatus.paused;

  factory AutoRunState.fromMap(Map<String, dynamic> m) {
    final configRaw = m['config'];
    final config = configRaw is Map<String, dynamic>
        ? AutoRunConfig.fromJson(configRaw)
        : const AutoRunConfig();
    return AutoRunState(
      id: m['id'] as String?,
      status: _parseAutoRunStatus(m['status'] as String?),
      config: config,
      currentQuerySourceId: m['current_query_source_id'] as int?,
      queriesCompleted: m['queries_completed'] as int? ?? 0,
      newRestaurants: m['new_restaurants'] as int? ?? 0,
      existingMatched: m['existing_matched'] as int? ?? 0,
      skippedNoImage: m['skipped_no_image'] as int? ?? 0,
      failedCandidates: m['failed_candidates'] as int? ?? 0,
      totalCostUsd: (m['total_cost_usd'] as num?)?.toDouble() ?? 0,
      stopReason: m['stop_reason'] as String?,
      startedAt: m['started_at'] != null
          ? DateTime.tryParse(m['started_at'] as String)
          : null,
      completedAt: m['completed_at'] != null
          ? DateTime.tryParse(m['completed_at'] as String)
          : null,
    );
  }

  AutoRunState copyWith({
    String? id,
    AutoRunStatus? status,
    AutoRunConfig? config,
    int? currentQuerySourceId,
    int? queriesCompleted,
    int? newRestaurants,
    int? existingMatched,
    int? skippedNoImage,
    int? failedCandidates,
    double? totalCostUsd,
    String? stopReason,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return AutoRunState(
      id: id ?? this.id,
      status: status ?? this.status,
      config: config ?? this.config,
      currentQuerySourceId: currentQuerySourceId ?? this.currentQuerySourceId,
      queriesCompleted: queriesCompleted ?? this.queriesCompleted,
      newRestaurants: newRestaurants ?? this.newRestaurants,
      existingMatched: existingMatched ?? this.existingMatched,
      skippedNoImage: skippedNoImage ?? this.skippedNoImage,
      failedCandidates: failedCandidates ?? this.failedCandidates,
      totalCostUsd: totalCostUsd ?? this.totalCostUsd,
      stopReason: stopReason ?? this.stopReason,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

AutoRunStatus _parseAutoRunStatus(String? value) {
  switch (value) {
    case 'running':
      return AutoRunStatus.running;
    case 'paused':
      return AutoRunStatus.paused;
    case 'completed':
      return AutoRunStatus.completed;
    case 'failed':
      return AutoRunStatus.failed;
    case 'stopped':
      return AutoRunStatus.stopped;
    default:
      return AutoRunStatus.idle;
  }
}

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
    required this.scrapeCount,
    required this.postsScraped,
    required this.restaurantCandidates,
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
  final int scrapeCount;
  final int postsScraped;
  final int restaurantCandidates;
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
        scrapeCount: m['scrape_count'] as int? ?? 0,
        postsScraped: m['posts_scraped'] as int? ?? 0,
        restaurantCandidates: m['restaurant_candidates'] as int? ?? 0,
        newRestaurants: m['new_restaurants'] as int? ?? 0,
        yieldRate: (m['yield_rate'] as num?)?.toDouble() ?? 0,
        totalCostUsd: (m['total_cost_usd'] as num?)?.toDouble() ?? 0,
        costPerNewRestaurant: (m['cost_per_new_restaurant'] as num?)
            ?.toDouble(),
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
    this.sourceId,
    this.sourceType,
    this.sourceValue,
    this.sourceArea,
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
  final int? sourceId;
  final String? sourceType;
  final String? sourceValue;
  final String? sourceArea;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? error;

  factory ScrapeRunSummary.fromMap(Map<String, dynamic> m) {
    final embeddedSource = m['discovery_sources'];
    final source = embeddedSource is Map
        ? Map<String, dynamic>.from(embeddedSource)
        : null;
    return ScrapeRunSummary(
      id: m['id'] as String,
      status: m['status'] as String? ?? 'pending',
      postsReceived: m['posts_received'] as int? ?? 0,
      newPosts: m['new_posts'] as int? ?? 0,
      newRestaurants: m['new_restaurants'] as int? ?? 0,
      costUsd: (m['cost_usd'] as num?)?.toDouble() ?? 0,
      sourceId: m['source_id'] as int?,
      sourceType: source?['source_type'] as String?,
      sourceValue: source?['source_value'] as String?,
      sourceArea: source?['area'] as String?,
      startedAt: m['started_at'] != null
          ? DateTime.tryParse(m['started_at'] as String)
          : null,
      completedAt: m['completed_at'] != null
          ? DateTime.tryParse(m['completed_at'] as String)
          : null,
      error: m['error'] as String?,
    );
  }
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
    this.resultLimit = 30,
    this.persistedResult,
    this.persistedScanTime,
    this.discoverySources = const [],
    this.recentRuns = const [],
    this.autoRun,
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
  final AutoRunState? autoRun;

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
    AutoRunState? autoRun,
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
      autoRun: autoRun ?? this.autoRun,
    );
  }
}
