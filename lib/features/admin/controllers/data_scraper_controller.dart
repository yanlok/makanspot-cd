import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/data_scraper_models.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class DataScraperController extends StateNotifier<PipelineState> {
  DataScraperController()
    : super(const PipelineState(status: PipelineStatus.idle)) {
    _init();
  }

  final _supabase = Supabase.instance.client;
  Timer? _pollTimer;
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _pollTimer?.cancel();
    super.dispose();
  }

  void _updateState(PipelineState Function(PipelineState) update) {
    if (_isDisposed) return;
    state = update(state);
  }

  static const _persistedKey = 'v2_data_scraper_last_scan';
  static const _persistedJobId = 'v2_active_job_id';
  static const _persistedRunId = 'v2_active_run_id';
  static const _persistedAutoRunId = 'v2_active_auto_run_id';

  Future<void> _loadPersistedResult() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_persistedKey);
      if (raw != null) {
        final timestamp = DateTime.parse(raw);
        _updateState((s) => s.copyWith(persistedScanTime: timestamp));
      }
    } catch (e) {
      developer.log('Failed to load persisted scan: $e', name: 'DataScraper');
    }
  }

  Future<void> _persistLastScan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _persistedKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e) {
      developer.log('Failed to persist scan: $e', name: 'DataScraper');
    }
  }

  Future<void> _persistActiveJob(String jobId, String runId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_persistedJobId, jobId);
      await prefs.setString(_persistedRunId, runId);
    } catch (e) {
      developer.log('Failed to persist active job: $e', name: 'DataScraper');
    }
  }

  Future<void> _clearActiveJob() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_persistedJobId);
      await prefs.remove(_persistedRunId);
    } catch (e) {
      developer.log('Failed to clear active job: $e', name: 'DataScraper');
    }
  }

  Future<(String?, String?)> _loadActiveJob() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (
        prefs.getString(_persistedJobId),
        prefs.getString(_persistedRunId),
      );
    } catch (e) {
      return (null, null);
    }
  }

  Future<void> _persistAutoRunId(String autoRunId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_persistedAutoRunId, autoRunId);
    } catch (e) {
      developer.log('Failed to persist auto-run id: $e', name: 'DataScraper');
    }
  }

  Future<void> _clearAutoRunId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_persistedAutoRunId);
    } catch (e) {
      developer.log('Failed to clear auto-run id: $e', name: 'DataScraper');
    }
  }

  Future<String?> _loadAutoRunId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_persistedAutoRunId);
    } catch (e) {
      return null;
    }
  }

  Future<void> _init() async {
    _updateState((s) => s.copyWith(initMessage: 'Loading stats...'));
    await _loadStats();
    if (!_isDisposed) await _loadPersistedResult();

    // Check for a persisted active auto-run first
    final persistedAutoRunId = await _loadAutoRunId();
    if (!_isDisposed && persistedAutoRunId != null) {
      await _reconnectAutoRun(persistedAutoRunId);
    } else {
      // Resume any persisted active job
      final (persistedJobId, persistedRunId) = await _loadActiveJob();
      if (!_isDisposed && persistedRunId != null) {
        _updateState(
          (s) => s.copyWith(
            status: PipelineStatus.processing,
            currentStep: PipelineStep.ingest,
            stepMessage: 'Reconnecting to active scan...',
            activeJobId: persistedJobId,
            activeRunId: persistedRunId,
          ),
        );
        _startPolling(persistedRunId, jobId: persistedJobId);
      } else if (!_isDisposed) {
        await _checkForActiveRuns();
      }
    }

    if (!_isDisposed && state.status == PipelineStatus.idle) {
      _updateState((s) => s.copyWith(initMessage: ''));
    }
  }

  /// Reconnect to an existing auto-run session from a previous app session.
  Future<void> _reconnectAutoRun(String autoRunId) async {
    try {
      final resp = await _supabase.functions.invoke(
        'pipeline-status',
        body: {'auto_run_id': autoRunId},
      );
      final data = resp.data as Map<String, dynamic>?;
      final autoRunData = data?['auto_run'] as Map<String, dynamic>?;
      if (autoRunData == null) {
        await _clearAutoRunId();
        return;
      }
      final autoRun = AutoRunState.fromMap(autoRunData);
      if (!autoRun.isActive) {
        await _clearAutoRunId();
        _updateState((s) => s.copyWith(autoRun: autoRun));
        return;
      }

      _updateState(
        (s) => s.copyWith(
          status: PipelineStatus.processing,
          stepMessage: 'Reconnecting to auto-run...',
          autoRun: autoRun,
        ),
      );

      // Start polling the auto-run
      if (!_isDisposed) {
        _startAutoRunPolling(autoRunId);
      }
    } catch (e) {
      developer.log('Failed to reconnect auto-run: $e', name: 'DataScraper');
      await _clearAutoRunId();
    }
  }

  /// Load aggregate stats from tables.
  Future<void> _loadStats() async {
    try {
      final restaurantCount = await _supabase
          .from('restaurants')
          .select('id')
          .count();
      final postCount = await _supabase
          .from('scraped_posts')
          .select('id')
          .count();
      final costRows = await _supabase
          .from('scrape_runs')
          .select('cost_usd')
          .eq('status', 'completed');
      final sources = await _loadAllDiscoverySources();
      final runs = await _supabase
          .from('scrape_runs')
          .select(
            'id, source_id, status, started_at, completed_at, posts_received, '
            'new_posts, restaurant_candidates, new_restaurants, cost_usd, error, '
            'created_at, discovery_sources(source_type, source_value, area, created_at)',
          )
          .order('created_at', ascending: false)
          .limit(10);

      double totalCost = 0;
      for (final row in costRows) {
        totalCost += (row['cost_usd'] as num?)?.toDouble() ?? 0;
      }

      final discoverySources = sources
          .map((m) => DiscoverySourceSummary.fromMap(m))
          .toList();

      final recentRuns = runs.map((m) => ScrapeRunSummary.fromMap(m)).toList();

      _updateState(
        (s) => s.copyWith(
          totalRestaurants: restaurantCount.count,
          totalPosts: postCount.count,
          totalCostUsd: totalCost,
          discoverySources: discoverySources,
          recentRuns: recentRuns,
        ),
      );
    } catch (e) {
      developer.log('Failed to load stats: $e', name: 'DataScraper');
    }
  }

  /// PostgREST applies a server-side maximum row count, so fetch ordered pages
  /// until every discovery source has been loaded.
  Future<List<Map<String, dynamic>>> _loadAllDiscoverySources() async {
    const pageSize = 500;
    final rows = <Map<String, dynamic>>[];

    for (var from = 0; ; from += pageSize) {
      final page = await _supabase
          .from('discovery_sources')
          .select()
          .order('new_restaurants', ascending: false)
          .order('yield_rate', ascending: false)
          .order('posts_scraped', ascending: false)
          .order('last_scraped_at', ascending: false, nullsFirst: false)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .range(from, from + pageSize - 1);
      rows.addAll(page.map(Map<String, dynamic>.from));
      if (page.length < pageSize) break;
    }

    return rows;
  }

  /// Check for active scrape runs.
  Future<void> _checkForActiveRuns() async {
    try {
      final resp = await _supabase.functions.invoke(
        'pipeline-status',
        body: {},
      );
      final data = resp.data as Map<String, dynamic>?;
      if (data == null) return;

      final activeRun = data['active_run'] as Map<String, dynamic>?;
      if (activeRun != null && activeRun['status'] == 'running') {
        final runId = activeRun['id'] as String;
        _updateState(
          (s) => s.copyWith(
            status: PipelineStatus.processing,
            currentStep: PipelineStep.ingest,
            stepMessage: 'Reconnecting to active scan...',
            activeRunId: runId,
          ),
        );
        _startPolling(runId);
      }
    } catch (e) {
      developer.log('Failed to check active runs: $e', name: 'DataScraper');
    }
  }

  /// Start a new pipeline scan.
  Future<void> startScan() async {
    if (state.status == PipelineStatus.scanning ||
        state.status == PipelineStatus.processing) {
      return;
    }

    _updateState(
      (s) => s.copyWith(
        status: PipelineStatus.scanning,
        currentStep: PipelineStep.scrape,
        stepMessage: 'Starting pipeline...',
        error: null,
        result: null,
        activeRunId: null,
      ),
    );

    try {
      final triggerResp = await _supabase.functions.invoke(
        'trigger-pipeline',
        body: {'result_limit': state.resultLimit},
      );

      final data = triggerResp.data as Map<String, dynamic>?;
      final jobId = data?['job_id'] as String?;
      final runId = data?['run_id'] as String?;

      if (runId == null) {
        final errorMsg = data?['error'] as String? ?? 'No run ID returned';
        throw Exception(errorMsg);
      }

      _updateState((s) => s.copyWith(activeJobId: jobId, activeRunId: runId));
      await _persistActiveJob(jobId ?? '', runId);

      if (!_isDisposed) {
        _startPolling(runId, jobId: jobId);
      }
    } on FunctionException catch (e) {
      String message = 'Scan could not start.';
      if (e.status == 409) {
        final details = e.details;
        if (details is Map) {
          message =
              (details as Map<String, dynamic>)['message'] as String? ??
              message;
        }
      }
      _updateState(
        (s) => s.copyWith(status: PipelineStatus.error, error: message),
      );
    } catch (e) {
      _updateState(
        (s) => s.copyWith(status: PipelineStatus.error, error: e.toString()),
      );
    }
  }

  /// Gracefully abort paid actors and close the active database lifecycle.
  Future<void> cancelScan() async {
    final runId = state.activeRunId;
    if (runId == null) return;
    _pollTimer?.cancel();
    _updateState((s) => s.copyWith(stepMessage: 'Cancelling scan...'));
    try {
      final response = await _supabase.functions.invoke(
        'cancel-pipeline',
        body: {'run_id': runId},
      );
      final result = response.data as Map<String, dynamic>?;
      if (result?['cancelled'] != true) {
        _updateState(
          (s) => s.copyWith(
            status: PipelineStatus.processing,
            stepMessage: 'Actor abort is pending. Tap Stop scan to retry.',
          ),
        );
        return;
      }
      await _clearActiveJob();
      _updateState(
        (s) => s.copyWith(
          status: PipelineStatus.error,
          error: 'Scan cancelled. Existing restaurant data was preserved.',
          activeRunId: null,
          activeJobId: null,
        ),
      );
      await _loadStats();
    } catch (e) {
      _updateState(
        (s) => s.copyWith(
          status: PipelineStatus.error,
          error: 'Could not cancel scan: $e',
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Auto Run methods
  // -------------------------------------------------------------------------

  /// Start a new auto-run session.
  Future<void> startAutoRun({
    int resultsPerQuery = 30,
    int maxQueries = 10,
    double costLimitUsd = 5.0,
  }) async {
    if (state.status == PipelineStatus.scanning ||
        state.status == PipelineStatus.processing) {
      return;
    }

    _updateState(
      (s) => s.copyWith(
        status: PipelineStatus.scanning,
        stepMessage: 'Starting auto-run...',
        error: null,
        result: null,
      ),
    );

    try {
      final resp = await _supabase.functions.invoke(
        'auto-run',
        body: {
          'action': 'start',
          'config': {
            'results_per_query': resultsPerQuery,
            'max_queries': maxQueries,
            'cost_limit_usd': costLimitUsd,
          },
        },
      );

      final data = resp.data as Map<String, dynamic>?;
      final autoRunId = data?['auto_run_id'] as String?;

      if (autoRunId == null) {
        final errorMsg = data?['error'] as String? ?? 'No auto-run ID returned';
        final message = data?['message'] as String? ?? errorMsg;
        throw Exception(message);
      }

      await _persistAutoRunId(autoRunId);

      // Fetch initial auto-run state
      final statusResp = await _supabase.functions.invoke(
        'pipeline-status',
        body: {'auto_run_id': autoRunId},
      );
      final statusData = statusResp.data as Map<String, dynamic>?;
      final autoRunData = statusData?['auto_run'] as Map<String, dynamic>?;
      final autoRun = autoRunData != null
          ? AutoRunState.fromMap(autoRunData)
          : const AutoRunState();

      _updateState(
        (s) => s.copyWith(
          status: PipelineStatus.processing,
          stepMessage: 'Auto-run started...',
          autoRun: autoRun,
        ),
      );

      if (!_isDisposed) {
        _startAutoRunPolling(autoRunId);
      }
    } on FunctionException catch (e) {
      String message = 'Auto-run could not start.';
      if (e.status == 409) {
        final details = e.details;
        if (details is Map) {
          message =
              (details as Map<String, dynamic>)['message'] as String? ??
              message;
        }
      }
      _updateState(
        (s) => s.copyWith(status: PipelineStatus.error, error: message),
      );
    } catch (e) {
      _updateState(
        (s) => s.copyWith(status: PipelineStatus.error, error: e.toString()),
      );
    }
  }

  /// Pause the active auto-run.
  Future<void> pauseAutoRun() async {
    final autoRunId = state.autoRun?.id;
    if (autoRunId == null) return;

    try {
      final resp = await _supabase.functions.invoke(
        'auto-run',
        body: {'action': 'pause', 'auto_run_id': autoRunId},
      );
      final data = resp.data as Map<String, dynamic>?;
      if (data?['error'] != null) {
        developer.log(
          'Server rejected pause: ${data!['error']}',
          name: 'DataScraper',
        );
        return;
      }
      _updateState(
        (s) => s.copyWith(
          stepMessage: 'Auto-run paused',
          autoRun: s.autoRun?.copyWith(status: AutoRunStatus.paused),
        ),
      );
    } catch (e) {
      developer.log('Failed to pause auto-run: $e', name: 'DataScraper');
    }
  }

  /// Resume a paused auto-run.
  Future<void> resumeAutoRun() async {
    final autoRunId = state.autoRun?.id;
    if (autoRunId == null) return;

    try {
      final resp = await _supabase.functions.invoke(
        'auto-run',
        body: {'action': 'resume', 'auto_run_id': autoRunId},
      );
      final data = resp.data as Map<String, dynamic>?;
      if (data?['error'] != null) {
        developer.log(
          'Server rejected resume: ${data!['error']}',
          name: 'DataScraper',
        );
        return;
      }
      _updateState(
        (s) => s.copyWith(
          status: PipelineStatus.processing,
          stepMessage: 'Resuming auto-run...',
          autoRun: s.autoRun?.copyWith(status: AutoRunStatus.running),
        ),
      );
      if (!_isDisposed) {
        _startAutoRunPolling(autoRunId);
      }
    } catch (e) {
      developer.log('Failed to resume auto-run: $e', name: 'DataScraper');
    }
  }

  /// Stop the active auto-run.
  Future<void> stopAutoRun() async {
    final autoRunId = state.autoRun?.id;
    if (autoRunId == null) return;

    _pollTimer?.cancel();
    _updateState((s) => s.copyWith(stepMessage: 'Stopping auto-run...'));

    try {
      await _supabase.functions.invoke(
        'auto-run',
        body: {'action': 'stop', 'auto_run_id': autoRunId},
      );
      await _clearAutoRunId();

      // Fetch final state
      final statusResp = await _supabase.functions.invoke(
        'pipeline-status',
        body: {'auto_run_id': autoRunId},
      );
      final statusData = statusResp.data as Map<String, dynamic>?;
      final autoRunData = statusData?['auto_run'] as Map<String, dynamic>?;
      final autoRun = autoRunData != null
          ? AutoRunState.fromMap(autoRunData)
          : null;

      _updateState(
        (s) => s.copyWith(
          status: PipelineStatus.complete,
          stepMessage: 'Auto-run stopped',
          autoRun: autoRun,
          activeRunId: null,
          activeJobId: null,
        ),
      );
      await _loadStats();
    } catch (e) {
      _updateState(
        (s) => s.copyWith(
          status: PipelineStatus.error,
          error: 'Could not stop auto-run: $e',
        ),
      );
    }
  }

  /// Poll auto-run progress periodically.
  void _startAutoRunPolling(String autoRunId, {int attempt = 0}) {
    _pollTimer?.cancel();
    const maxAttempts = 600; // 50 minutes at 5s intervals

    _pollTimer = Timer(const Duration(seconds: 5), () async {
      if (_isDisposed) return;

      final nextAttempt = attempt + 1;
      if (nextAttempt >= maxAttempts) {
        await _clearAutoRunId();
        _updateState(
          (s) => s.copyWith(
            status: PipelineStatus.error,
            error: 'Auto-run timed out after 50 minutes',
            autoRun: null,
            activeRunId: null,
            activeJobId: null,
          ),
        );
        return;
      }

      try {
        final resp = await _supabase.functions.invoke(
          'pipeline-status',
          body: {'auto_run_id': autoRunId},
        );
        final data = resp.data as Map<String, dynamic>?;
        final autoRunData = data?['auto_run'] as Map<String, dynamic>?;

        if (autoRunData == null) {
          await _clearAutoRunId();
          _updateState(
            (s) => s.copyWith(
              status: PipelineStatus.complete,
              stepMessage: 'Auto-run finished',
              autoRun: null,
            ),
          );
          await _loadStats();
          return;
        }

        final autoRun = AutoRunState.fromMap(autoRunData);

        // Check if auto-run has finished
        if (!autoRun.isActive) {
          await _clearAutoRunId();
          _updateState(
            (s) => s.copyWith(
              status: PipelineStatus.complete,
              stepMessage: autoRun.stopReason ?? 'Auto-run finished',
              autoRun: autoRun,
              activeRunId: null,
              activeJobId: null,
            ),
          );
          await _loadStats();
          return;
        }

        // Still active — update state and continue polling
        final activeRun = data?['active_run'] as Map<String, dynamic>?;
        final stepMessage = activeRun != null
            ? 'Query ${autoRun.queriesCompleted + 1} in progress...'
            : 'Preparing next query...';

        _updateState(
          (s) => s.copyWith(
            status: PipelineStatus.processing,
            stepMessage: stepMessage,
            autoRun: autoRun,
          ),
        );

        if (!_isDisposed) {
          _startAutoRunPolling(autoRunId, attempt: nextAttempt);
        }
      } catch (e) {
        developer.log('Auto-run poll failed: $e', name: 'DataScraper');
        if (!_isDisposed) {
          _startAutoRunPolling(autoRunId, attempt: nextAttempt);
        }
      }
    });
  }

  /// Set the result limit for the next scan.
  void setResultLimit(int limit) {
    _updateState((s) => s.copyWith(resultLimit: limit.clamp(20, 40)));
  }

  void _startPolling(String runId, {String? jobId, int attempt = 0}) {
    _pollTimer?.cancel();
    const maxAttempts = 180;

    _pollTimer = Timer(const Duration(seconds: 5), () async {
      if (_isDisposed) return;

      final nextAttempt = attempt + 1;
      if (nextAttempt >= maxAttempts) {
        await _clearActiveJob();
        _updateState(
          (s) => s.copyWith(
            status: PipelineStatus.error,
            error: 'Scan timed out after 15 minutes',
            activeRunId: null,
            activeJobId: null,
          ),
        );
        return;
      }

      final result = await _checkRunStatus(runId);
      if (result != null) {
        await _clearActiveJob();
        _handleCompletion(result);
        return;
      }

      if (!_isDisposed) {
        _startPolling(runId, jobId: jobId, attempt: nextAttempt);
      }
    });
  }

  Future<Map<String, dynamic>?> _checkRunStatus(String runId) async {
    try {
      final resp = await _supabase.functions.invoke(
        'pipeline-status',
        body: {'run_id': runId},
      );

      final data = resp.data as Map<String, dynamic>?;
      if (data == null) return null;

      // Use specific_run when available (direct match by run_id)
      final specificRun = data['specific_run'] as Map<String, dynamic>?;
      if (specificRun != null) {
        final runStatus = specificRun['status'] as String? ?? 'running';
        if (runStatus == 'completed' || runStatus == 'failed') {
          return {
            'status': runStatus,
            'posts_received': specificRun['posts_received'],
            'new_posts': specificRun['new_posts'],
            'new_restaurants': specificRun['new_restaurants'],
            'cost_usd': specificRun['cost_usd'],
            'error': specificRun['error'],
          };
        }

        // Still running — update progress from stats
        final stats = data['stats'] as Map<String, dynamic>?;
        if (stats != null) {
          final step = _inferStep(specificRun);
          _updateState(
            (s) => s.copyWith(
              currentStep: step,
              stepMessage: _stepMessage(step, stats),
            ),
          );
        }
        return null;
      }

      return null;
    } catch (e) {
      developer.log('Status check failed: $e', name: 'DataScraper');
      return null;
    }
  }

  PipelineStep _inferStep(Map<String, dynamic> run) {
    final status = run['status'] as String? ?? 'running';
    if (status == 'completed' || status == 'failed') {
      return PipelineStep.metrics;
    }

    final posts = run['posts_received'] as int? ?? 0;
    final restaurants = run['new_restaurants'] as int? ?? 0;

    if (posts == 0) return PipelineStep.scrape;
    if (restaurants == 0) return PipelineStep.detect;
    return PipelineStep.enrich;
  }

  String _stepMessage(PipelineStep step, Map<String, dynamic> stats) {
    final posts = stats['total_posts'] as int? ?? 0;
    final pending = stats['pending'] as int? ?? 0;
    final promoted = stats['promoted'] as int? ?? 0;
    final restaurants = stats['total_restaurants'] as int? ?? 0;

    switch (step) {
      case PipelineStep.scrape:
        return 'Scraping Instagram...';
      case PipelineStep.ingest:
        return 'Ingesting posts... ($posts total)';
      case PipelineStep.detect:
        return 'Detecting restaurants... ($pending pending)';
      case PipelineStep.resolve:
        return 'Resolving candidates...';
      case PipelineStep.enrich:
        return 'Enriching restaurants... ($promoted promoted)';
      case PipelineStep.metrics:
        return 'Updating metrics... ($restaurants restaurants)';
    }
  }

  void _handleCompletion(Map<String, dynamic> statusData) {
    final runStatus = statusData['status'] as String? ?? 'completed';

    if (runStatus == 'failed') {
      _updateState(
        (s) => s.copyWith(
          status: PipelineStatus.error,
          error: statusData['error'] as String? ?? 'Scan failed',
          activeRunId: null,
          activeJobId: null,
        ),
      );
      return;
    }

    final scanResult = ScanResult(
      postsReceived: statusData['posts_received'] as int? ?? 0,
      newPosts: statusData['new_posts'] as int? ?? 0,
      restaurantCandidates: 0,
      newRestaurants: statusData['new_restaurants'] as int? ?? 0,
      verifiedRestaurants: 0,
      costUsd: (statusData['cost_usd'] as num?)?.toDouble() ?? 0,
    );

    _updateState(
      (s) => s.copyWith(
        status: PipelineStatus.complete,
        currentStep: PipelineStep.metrics,
        stepMessage: 'Complete!',
        result: scanResult,
        lastScanTime: DateTime.now(),
        activeRunId: null,
        activeJobId: null,
      ),
    );

    _persistLastScan();
    _loadStats();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final dataScraperControllerProvider =
    StateNotifierProvider<DataScraperController, PipelineState>(
      (ref) => DataScraperController(),
    );
