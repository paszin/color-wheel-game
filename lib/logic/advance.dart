import 'dart:math';

/// Games in a row without a win after which the next level may be opened
/// anyway.
const lossesBeforeSkip = 3;

/// A loss is close when the gap in the final standing is at most 10 % of
/// the winner's total, and never less than 3 points. A draw counts as close.
bool isCloseLoss(int mine, int theirs) {
  final gap = theirs - mine;
  if (gap < 0) return false;
  return gap <= max(3, (theirs * 0.1).ceil());
}

/// Why the player may move on without winning, or null if they may not.
enum SkipReason { closeLoss, manyLosses }

SkipReason? skipReason({
  required int mine,
  required int theirs,
  required int lossesInRow,
}) {
  if (mine > theirs) return null;
  if (isCloseLoss(mine, theirs)) return SkipReason.closeLoss;
  if (lossesInRow >= lossesBeforeSkip) return SkipReason.manyLosses;
  return null;
}
