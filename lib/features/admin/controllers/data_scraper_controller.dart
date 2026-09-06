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
          .limit(200);


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

      // 1. Check if an auto-run is active in the backend
      final autoRunData = data['auto_run'] as Map<String, dynamic>?;
      if (autoRunData != null) {
        final autoRun = AutoRunState.fromMap(autoRunData);
        if (autoRun.isActive) {
          final runId = autoRun.id ?? autoRunData['id']?.toString();
          if (runId != null && runId.isNotEmpty) {
            await _persistAutoRunId(runId);
            _updateState(
              (s) => s.copyWith(
                status: PipelineStatus.processing,
                stepMessage: 'Reconnecting to auto-run...',
                autoRun: autoRun,
                result: null,
              ),
            );
            _startAutoRunPolling(runId);
            return;
          }
        }
      }

      // 2. Only reconnect to active scrape run if it is a standalone single scan
      final activeRun = data['active_run'] as Map<String, dynamic>?;
      if (activeRun != null && activeRun['status'] == 'running') {
        final autoRunId = activeRun['auto_run_id']?.toString();
        if (autoRunId != null && autoRunId.isNotEmpty) {
          // This scrape run belongs to an auto-run session
          await _persistAutoRunId(autoRunId);
          await _reconnectAutoRun(autoRunId);
          return;
        }

        final runId = activeRun['id'] as String;
        _updateState(
          (s) => s.copyWith(
            status: PipelineStatus.processing,
            currentStep: PipelineStep.ingest,
            stepMessage: 'Reconnecting to active scan...',
            activeRunId: runId,
            autoRun: null,
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
        autoRun: null,
        activeRunId: null,
        latestDiscoveredRestaurant: null,
        activeHashtag: null,
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
        autoRun: null,
        latestDiscoveredRestaurant: null,
        activeHashtag: null,
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
              result: null,
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
              result: null,
              activeRunId: null,
              activeJobId: null,
            ),
          );
          await _loadStats();
          return;
        }

        // Still active — update state and continue polling
        final activeRun = data?['active_run'] as Map<String, dynamic>?;
        final sourceData = activeRun?['discovery_sources'] as Map<String, dynamic>?;
        final activeHashtag = sourceData?['source_value'] as String? ?? state.activeHashtag;

        String? latestName = state.latestDiscoveredRestaurant;
        if (autoRun.newRestaurants > 0 &&
            (autoRun.newRestaurants != (state.autoRun?.newRestaurants ?? 0) ||
                latestName == null)) {
          try {
            final recent = await _supabase
                .from('restaurants')
                .select('name')
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();
            if (recent != null && recent['name'] != null) {
              latestName = recent['name'] as String;
            }
          } catch (e) {
            developer.log('Failed to fetch latest restaurant: $e', name: 'DataScraper');
          }
        }

        final stepMessage = activeRun != null
            ? 'Query ${autoRun.queriesCompleted + 1} in progress...'
            : 'Preparing next query...';

        _updateState(
          (s) => s.copyWith(
            status: PipelineStatus.processing,
            stepMessage: stepMessage,
            autoRun: autoRun,
            activeHashtag: activeHashtag,
            latestDiscoveredRestaurant: latestName,
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
    const maxAttempts = 450; // 15 minutes at 2s intervals

    _pollTimer = Timer(const Duration(seconds: 2), () async {
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

      // Use specific_run when available, fallback to active_run
      final specificRun =
          (data['specific_run'] ?? data['active_run']) as Map<String, dynamic>?;
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

        // Still running — update progress from real backend step & stats
        final globalStats = data['stats'] as Map<String, dynamic>? ?? {};
        final sourceData = specificRun['discovery_sources'] as Map<String, dynamic>?;
        final activeHashtag = sourceData?['source_value'] as String?;
        final rootCurrentStep = data['current_step'] as String?;

        String? latestName = state.latestDiscoveredRestaurant;
        final newRestCount = specificRun['new_restaurants'] as int? ?? 0;
        if (newRestCount > 0 && latestName == null) {
          try {
            final recent = await _supabase
                .from('restaurants')
                .select('name')
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();
            if (recent != null && recent['name'] != null) {
              latestName = recent['name'] as String;
            }
          } catch (_) {}
        }

        final step = _inferStep(
          specificRun,
          dataCurrentStep: rootCurrentStep,
        );

        _updateState(
          (s) => s.copyWith(
            currentStep: step,
            stepMessage: _stepMessage(step, globalStats, specificRun: specificRun),
            activeHashtag: activeHashtag ?? s.activeHashtag,
            latestDiscoveredRestaurant:
                latestName ?? s.latestDiscoveredRestaurant,
          ),
        );
        return null;
      }

      return null;
    } catch (e) {
      developer.log('Status check failed: $e', name: 'DataScraper');
      return null;
    }
  }

  PipelineStep _inferStep(
    Map<String, dynamic> run, {
    String? dataCurrentStep,
  }) {
    // 1. Check real current_step from backend pipeline state machine
    String? stepStr = dataCurrentStep;
    final result = run['result'];
    if (stepStr == null && result is Map<String, dynamic>) {
      stepStr = result['current_step'] as String?;
    }
    stepStr ??= run['current_step'] as String?;

    if (stepStr != null) {
      switch (stepStr) {
        case 'scrape':
        case 'location_posts_scrape':
          return PipelineStep.scrape;
        case 'ingest':
        case 'location_posts_ingest':
          return PipelineStep.ingest;
        case 'detect':
          return PipelineStep.detect;
        case 'resolve':
          return PipelineStep.resolve;
        case 'enrich':
          return PipelineStep.enrich;
        case 'metrics':
        case 'complete':
          return PipelineStep.metrics;
      }
    }

    final status = run['status'] as String? ?? 'running';
    if (status == 'completed' || status == 'failed') {
      return PipelineStep.metrics;
    }

    return PipelineStep.scrape;
  }

  String _stepMessage(
    PipelineStep step,
    Map<String, dynamic> stats, {
    Map<String, dynamic>? specificRun,
  }) {
    final runResult = specificRun?['result'] as Map<String, dynamic>?;
    final runStats = runResult?['stats'] as Map<String, dynamic>?;

    final runPosts = (runStats?['posts_received'] as int?) ??
        (specificRun?['posts_received'] as int?);
    final runCandidates = (runStats?['candidates_detected'] as int?) ??
        (specificRun?['restaurant_candidates'] as int?);
    final runRestaurants = (runStats?['restaurants_created'] as int?) ??
        (specificRun?['new_restaurants'] as int?);

    switch (step) {
      case PipelineStep.scrape:
        return 'Scraping Instagram content...';
      case PipelineStep.ingest:
        if (runPosts != null && runPosts > 0) {
          return 'Ingesting $runPosts Instagram posts...';
        }
        return 'Ingesting scraped posts...';
      case PipelineStep.detect:
        if (runCandidates != null && runCandidates > 0) {
          return 'Detecting restaurants ($runCandidates candidates)...';
        }
        return 'Detecting restaurant candidates with AI...';
      case PipelineStep.resolve:
        return 'Resolving locations & coordinates...';
      case PipelineStep.enrich:
        if (runRestaurants != null && runRestaurants > 0) {
          return 'Enriching restaurants ($runRestaurants created)...';
        }
        return 'Enriching restaurant details & cuisine...';
      case PipelineStep.metrics:
        return 'Evaluating social metrics & verifying photos...';
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
        autoRun: null,
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
