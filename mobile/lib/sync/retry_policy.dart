import 'dart:math';

typedef Sleep = Future<void> Function(Duration delay);

class RetryPolicy {
  RetryPolicy({
    this.maxAttemps = 4,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 8),
    Random? random,
    Sleep? sleep,
  }) : _random = random ?? Random(),
       _sleep = sleep ?? ((delay) => Future<void>.delayed(delay));

  final int maxAttemps;
  final Duration baseDelay;
  final Duration maxDelay;
  final Random _random;
  final Sleep _sleep;

  Duration delayFor(int attempt) {
    final exponential = baseDelay.inMilliseconds * (1 << (attempt - 1));
    final capped = min(exponential, maxDelay.inMilliseconds);
    final half = capped ~/ 2;
    return Duration(milliseconds: half + _random.nextInt(half + 1));
  }

  Future<T> run<T>(
    Future<T> Function() action, {
    required bool Function(Object error) retryIf,
  }) async {
    var attempt = 1;
    while (true) {
      try {
        return await action();
      } catch (error) {
        if (attempt >= maxAttemps || !retryIf(error)) rethrow;
        await _sleep(delayFor(attempt));
        attempt++;
      }
    }
  }
}
