const Self = @This();

const State = @import("State.zig");
const Board = State.Board;
const Piece = State.Board.Piece;
const Position = State.Position;

const Terminal = @import("Terminal.zig");
const Color = Terminal.Color;

const Ui = @import("Ui.zig");

// TODO: Use larger size
pub const HEIGHT = Board.SIZE * Ui.dims.CELL_HEIGHT;
pub const WIDTH = Board.SIZE * Ui.dims.CELL_WIDTH;

cells: [HEIGHT * WIDTH]Cell,

const Char = u21;

// TODO: Make more comprehensive
const Cell = struct {
    char: Char,
    fg: Color,
    bg: Color,
    bold: bool,

    pub fn eql(lhs: Cell, rhs: Cell) bool {
        return lhs.char == rhs.char and
            lhs.fg == rhs.fg and
            lhs.bg == rhs.bg and
            lhs.bold == rhs.bold;
    }
};

pub const CellOptions = struct {
    char: ?Char = null,
    fg: ?Color = null,
    bg: ?Color = null,
    bold: ?bool = null,

    /// Merge two [`CellOptions`], preferring values of `rhs`.
    pub fn join(lhs: CellOptions, rhs: CellOptions) CellOptions {
        return CellOptions{
            .char = rhs.char orelse lhs.char orelse null,
            .fg = rhs.fg orelse lhs.fg orelse null,
            .bg = rhs.bg orelse lhs.bg orelse null,
            .bold = rhs.bold orelse lhs.bold orelse null,
        };
    }
};

pub fn new(default_cell: CellOptions) Self {
    var self = Self{
        .cells = undefined,
    };
    for (0..HEIGHT) |y| {
        for (0..WIDTH) |x| {
            self.set(y, x, default_cell);
        }
    }
    return self;
}

pub fn set(
    self: *Self,
    y: usize,
    x: usize,
    options: CellOptions,
) void {
    var cell = &self.cells[y * WIDTH + x];
    if (options.char) |char| {
        cell.char = char;
    }
    if (options.fg) |fg| {
        cell.fg = fg;
    }
    if (options.bg) |bg| {
        cell.bg = bg;
    }
    if (options.bold) |bold| {
        cell.bold = bold;
    }
}

pub fn get(self: *Self, y: usize, x: usize) *Cell {
    return &self.cells[y * WIDTH + x];
}
