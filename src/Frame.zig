const Self = @This();

const State = @import("State.zig");
const Board = State.Board;
const Piece = State.Board.Piece;
const Position = State.Position;

const Terminal = @import("Terminal.zig");
const Attributes = Terminal.Attributes;
const Color = Terminal.Color;

const Ui = @import("Ui.zig");

// TODO: Use larger size
pub const HEIGHT = Board.SIZE * Ui.tile.HEIGHT;
pub const WIDTH = Board.SIZE * Ui.tile.WIDTH;

cells: [HEIGHT * WIDTH]Cell,

const Char = u21;

const Cell = struct {
    char: Char,
    attributes: Terminal.Attributes,

    pub fn eql(lhs: Cell, rhs: Cell) bool {
        return lhs.char == rhs.char and lhs.attributes.eql(rhs.attributes);
    }
};

// TODO: Add more style attributes
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

// TODO: Move logic to `Cell.apply`
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
        cell.attributes.fg = fg;
    }
    if (options.bg) |bg| {
        cell.attributes.bg = bg;
    }
    if (options.bold) |bold| {
        cell.attributes.style.bold = bold;
    }
}

pub fn get(self: *Self, y: usize, x: usize) *Cell {
    return &self.cells[y * WIDTH + x];
}
