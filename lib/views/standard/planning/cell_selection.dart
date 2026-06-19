
enum CellEditMode { none, selected, typingFromType, typingFromDouble }

const List<String> months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class CellPosition {
  final int row;
  final int col;
  const CellPosition(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellPosition &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

class CellRange {
  final CellPosition start;
  final CellPosition end;
  const CellRange(this.start, this.end);

  int get minRow => start.row < end.row ? start.row : end.row;
  int get maxRow => start.row > end.row ? start.row : end.row;
  int get minCol => start.col < end.col ? start.col : end.col;
  int get maxCol => start.col > end.col ? start.col : end.col;

  bool contains(int r, int c) {
    return r >= minRow && r <= maxRow && c >= minCol && c <= maxCol;
  }
}
