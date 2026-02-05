class FileExtensionException implements Exception {
  late final String? _validExtension;
  FileExtensionException({String? validExtension}) {
    _validExtension = validExtension;
  }

  @override
  String toString() {
    return _validExtension != null
        ? 'We only accept files in: "$_validExtension".'
        : 'We do not accept this extension.';
  }
}

class ClassException implements Exception {
  final String className, message;
  ClassException(this.className, this.message);

  @override
  String toString() {
    return '$className: $message';
  }
}

class ItineraryException extends ClassException {
  ItineraryException(String message) : super('Itinerary', message);
}

class PointItineraryException extends ClassException {
  PointItineraryException(String message) : super('PointItinerary', message);
}

class TrackException extends ClassException {
  TrackException(String message) : super('Track', message);
}

class LatLngCHESTException extends ClassException {
  LatLngCHESTException(String message) : super('LatLngCHEST', message);
}

class CategoryException extends ClassException {
  CategoryException(String message) : super('Category', message);
}

class CityException extends ClassException {
  CityException(String message) : super('City', message);
}

class FeatureException extends ClassException {
  FeatureException(String message) : super('Feature', message);
}

class SuggestionException extends ClassException {
  SuggestionException(String message) : super('Suggestion', message);
}

class ReSugException extends ClassException {
  ReSugException(String message) : super('ReSug', message);
}

class ReSugHeaderException extends ClassException {
  ReSugHeaderException(String message) : super('ReSugHeader', message);
}

class ReSugDataException extends ClassException {
  ReSugDataException(String message) : super('ReSugData', message);
}

class ReSelDataException extends ClassException {
  ReSelDataException(String message) : super('ReSelData', message);
}

class ReSugDicException extends ClassException {
  ReSugDicException(String message) : super('ReSugDic', message);
}

class TaskException extends ClassException {
  TaskException(String message) : super('Task', message);
}

class SpaceException extends ClassException {
  SpaceException(String message) : super('Space', message);
}

class AnswerException extends ClassException {
  AnswerException(String message) : super('Answer', message);
}

class FeedException extends ClassException {
  FeedException(String message) : super('Feed', message);
}

class FeederException extends ClassException {
  FeederException(String message) : super('Feeder', message);
}

class SubscriberException extends FeederException {
  SubscriberException(String message) : super('Subscriber $message');
}

class UserXESTException extends ClassException {
  UserXESTException(String message) : super('User_xEST', message);
}
