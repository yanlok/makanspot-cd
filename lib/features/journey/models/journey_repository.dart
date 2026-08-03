import 'journey_models.dart';

abstract interface class JourneyRepository {
  Future<JourneyData> loadJourney();
}
