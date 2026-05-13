package rl;

abstract RLHandle(Int) from Int to Int {
  public static inline function invalid(): RLHandle {
    return 0;
  }

  public inline function isValid(): Bool {
    return this != 0;
  }
}
