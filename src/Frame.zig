const Self = @This();

const State = @import("State.zig");
const Board = State.Board;
const Piece = State.Piece;
const Tile = State.Tile;

const Terminal = @import("Terminal.zig");
const Attributes = Terminal.Attributes;

const Ui = @import("Ui.zig");

// TODO: Use larger size
pub const HEIGHT = Board.SIZE * Ui.tile_size.HEIGHT;
pub const WIDTH = Board.SIZE * Ui.tile_size.WIDTH;

cells: [HEIGHT * WIDTH]Cell,

const Char = u21;

pub fn new() Self {
    return Self{
        .cells = [1]Cell{.{}} ** (HEIGHT * WIDTH),
    };
}

pub fn set(self: *Self, y: usize, x: usize, options: Cell.Options) void {
    self.cells[y * WIDTH + x].apply(options);
}

pub fn get(self: *Self, y: usize, x: usize) *Cell {
    return &self.cells[y * WIDTH + x];
}

pub const Cell = struct {
    char: Char = ' ',
    attributes: Attributes = .{},

    pub fn eql(lhs: Cell, rhs: Cell) bool {
        return lhs.char == rhs.char and lhs.attributes.eql(rhs.attributes);
    }

    pub fn apply(self: *Cell, options: Options) void {
        if (options.char) |char| {
            self.char = char;
        }
        if (options.fg) |fg| {
            self.attributes.fg = fg;
        }
        if (options.bg) |bg| {
            self.attributes.bg = bg;
        }
        if (options.bold) |bold| {
            self.attributes.style.bold = bold;
        }
    }

    // TODO: Add more style attributes
    pub const Options = struct {
        char: ?Char = null,
        fg: ?Attributes.Color = null,
        bg: ?Attributes.Color = null,
        bold: ?bool = null,

        /// Merge two [`CellOptions`], preferring values of `rhs`.
        pub fn join(lhs: Options, rhs: Options) Options {
            return Options{
                .char = rhs.char orelse lhs.char orelse null,
                .fg = rhs.fg orelse lhs.fg orelse null,
                .bg = rhs.bg orelse lhs.bg orelse null,
                .bold = rhs.bold orelse lhs.bold orelse null,
            };
        }
    };
};
