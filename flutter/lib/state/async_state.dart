sealed class AsyncState<T> {
  const AsyncState();
}

final class Idle<T> extends AsyncState<T> {
  const Idle();
}

final class Loading<T> extends AsyncState<T> {
  const Loading();
}

final class Success<T> extends AsyncState<T> {
  const Success(this.data);
  final T data;
}

final class Empty<T> extends AsyncState<T> {
  const Empty();
}

final class Failure<T> extends AsyncState<T> {
  const Failure(this.message);
  final String message;
}

final class Offline<T> extends AsyncState<T> {
  const Offline();
}

final class Unauthorized<T> extends AsyncState<T> {
  const Unauthorized();
}
