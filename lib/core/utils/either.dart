/// Representa un valor que puede ser un fallo (Left) o un éxito (Right).
class Either<L, R> {
  final L? _left;
  final R? _right;

  Either.left(L left)
      : assert(left != null, 'Left value cannot be null'),
        _left = left,
        _right = null;

  Either.right(R right)
      : _left = null,
        _right = right;

  /// Constructor para resultados exitosos sin valor.
  static Either<L, void> rightVoid<L>() => Either<L, void>.right(null);

  bool get isLeft => _left != null;
  bool get isRight => _left == null;

  L get left {
    if (!isLeft) throw StateError('Either is Right, cannot access left value');
    return _left as L;
  }

  R get right {
    if (!isRight) throw StateError('Either is Left, cannot access right value');
    return _right as R;
  }

  T fold<T>(T Function(L) onLeft, T Function(R) onRight) {
    if (isLeft) return onLeft(_left as L);
    return onRight(_right as R);
  }

  Either<L, T> map<T>(T Function(R) f) {
    if (isRight) return Either.right(f(_right as R));
    return Either.left(_left as L);
  }

  Either<L, T> flatMap<T>(Either<L, T> Function(R) f) {
    if (isRight) return f(_right as R);
    return Either.left(_left as L);
  }
}
