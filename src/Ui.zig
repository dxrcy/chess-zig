const Self = @This();

const std = @import("std");
const assert = std.debug.assert;
const posix = std.posix;

const State = @import("State.zig");
const Board = State.Board;
const Position = State.Position;

const Terminal = @import("Terminal.zig");
const Color = Terminal.Color;

terminal: Terminal,
frame: Frame,
ascii: bool,

const Frame = struct {
    // TODO: Use larger size
    const HEIGHT = Board.SIZE * CELL_HEIGHT;
    const LENGTH = Board.SIZE * CELL_LENGTH;

    cells: [HEIGHT * LENGTH]Cell,

    // TODO: Use `u21` ?
    const Char = []const u8;

    // TODO: Make more comprehensive
    const Cell = struct {
        // TODO: Support UTF-8
        char: Char,
        fg: Color,
        bg: Color,
        bold: bool,
    };

    const CellOptions = struct {
        char: ?Char = null,
        fg: ?Color = null,
        bg: ?Color = null,
        bold: ?bool = null,
    };

    // TODO: Set attributes separately
    pub fn set(
        self: *Frame,
        y: usize,
        x: usize,
        options: CellOptions,
    ) void {
        var cell = &self.cells[y * LENGTH + x];
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

    pub fn get(self: *Frame, y: usize, x: usize) Cell {
        return self.cells[y * LENGTH + x];
    }
};

// TODO: Rename "*_LENGTH" -> "*_WIDTH"
const PIECE_LENGTH: usize = 3;
const PIECE_HEIGHT: usize = 3;

const PADDING_LEFT: usize = 3;
const PADDING_RIGHT: usize = 3;
const PADDING_TOP: usize = 1;
const PADDING_BOTTOM: usize = 1;

const CELL_LENGTH: usize = PIECE_LENGTH + PADDING_LEFT + PADDING_RIGHT;
const CELL_HEIGHT: usize = PIECE_HEIGHT + PADDING_TOP + PADDING_BOTTOM;

const Edge = enum {
    left,
    right,
    top,
    bottom,
    top_left,
    top_right,
    bottom_left,
    bottom_right,

    /// Character count (not bytes) of any edge character.
    const LENGTH = 1;
};

pub fn new(ascii: bool) Self {
    var self = Self{
        .terminal = Terminal.new(),
        .ascii = ascii,
        .frame = undefined,
    };
    for (0..Frame.HEIGHT) |y| {
        for (0..Frame.LENGTH) |x| {
            self.frame.set(y, x, .{
                .char = " ",
                .fg = .white,
                .bg = .black,
                .bold = false,
            });
        }
    }
    return self;
}

pub fn enter(self: *Self) !void {
    self.terminal.setAlternativeScreen(.enter);
    self.terminal.setCursorVisibility(.hidden);
    self.terminal.clearEntireScreen();
    self.terminal.flush();

    try self.terminal.saveTermios();
    var termios = self.terminal.getTermios() orelse unreachable;
    termios.lflag.ICANON = false;
    termios.lflag.ECHO = false;
    termios.lflag.ISIG = false;
    try self.terminal.setTermios(termios);
}

pub fn exit(self: *Self) !void {
    self.terminal.setCursorVisibility(.visible);
    self.terminal.setAlternativeScreen(.exit);
    self.terminal.flush();

    try self.terminal.restoreTermios();
}

pub fn render(self: *Self, state: *const State) void {
    self.terminal.setCursorPosition(1, 1);

    for (0..Board.SIZE) |row| {
        for (0..Board.SIZE) |col| {
            const is_even = (row + col) % 2 == 0;
            const bg: Color = if (is_even) .black else .white;

            for (0..CELL_HEIGHT) |y| {
                for (0..CELL_LENGTH) |x| {
                    self.frame.set(
                        row * CELL_HEIGHT + y,
                        col * CELL_LENGTH + x,
                        .{ .char = " ", .bg = bg },
                    );
                }
            }

            if (state.board.get(row, col)) |piece| {
                const string = piece.string();

                for (0..PIECE_HEIGHT) |y| {
                    for (0..PIECE_LENGTH) |x| {
                        const char = string[y * PIECE_HEIGHT + x ..][0..1];

                        self.frame.set(
                            row * CELL_HEIGHT + y + PADDING_TOP,
                            col * CELL_LENGTH + x + PADDING_LEFT,
                            .{ .char = char, .fg = .green, .bold = true },
                        );
                    }
                }
            }
        }
    }

    const cursor_fg: Color = if (state.active == .white) .blue else .red;

    for (1..CELL_LENGTH - 1) |x| {
        self.frame.set(
            state.cursor.row * CELL_HEIGHT,
            state.cursor.col * CELL_LENGTH + x,
            .{ .fg = cursor_fg, .char = self.getEdge(.top) },
        );
    }
    for (1..CELL_LENGTH - 1) |x| {
        self.frame.set(
            state.cursor.row * CELL_HEIGHT + CELL_HEIGHT - 1,
            state.cursor.col * CELL_LENGTH + x,
            .{ .fg = cursor_fg, .char = self.getEdge(.bottom) },
        );
    }
    for (1..CELL_HEIGHT - 1) |y| {
        self.frame.set(
            state.cursor.row * CELL_HEIGHT + y,
            state.cursor.col * CELL_LENGTH,
            .{ .fg = cursor_fg, .char = self.getEdge(.left) },
        );
    }
    for (1..CELL_HEIGHT - 1) |y| {
        self.frame.set(
            state.cursor.row * CELL_HEIGHT + y,
            state.cursor.col * CELL_LENGTH + CELL_LENGTH - 1,
            .{ .fg = cursor_fg, .char = self.getEdge(.right) },
        );
    }
    self.frame.set(
        state.cursor.row * CELL_HEIGHT,
        state.cursor.col * CELL_LENGTH,
        .{ .fg = cursor_fg, .char = self.getEdge(.top_left) },
    );
    self.frame.set(
        state.cursor.row * CELL_HEIGHT,
        state.cursor.col * CELL_LENGTH + CELL_LENGTH - 1,
        .{ .fg = cursor_fg, .char = self.getEdge(.top_right) },
    );
    self.frame.set(
        state.cursor.row * CELL_HEIGHT + CELL_HEIGHT - 1,
        state.cursor.col * CELL_LENGTH,
        .{ .fg = cursor_fg, .char = self.getEdge(.bottom_left) },
    );
    self.frame.set(
        state.cursor.row * CELL_HEIGHT + CELL_HEIGHT - 1,
        state.cursor.col * CELL_LENGTH + CELL_LENGTH - 1,
        .{ .fg = cursor_fg, .char = self.getEdge(.bottom_right) },
    );

    // PERF: Only update cells which changed from last frame
    for (0..Frame.HEIGHT) |y| {
        for (0..Frame.LENGTH) |x| {
            const cell = self.frame.get(y, x);
            // PERF: Only set attributes if changed from previous cell
            self.terminal.resetStyle();
            if (cell.bold) {
                self.terminal.setStyle(.bold);
            }
            self.terminal.setForeground(cell.fg);
            self.terminal.setBackground(cell.bg);
            self.terminal.print("{s}", .{cell.char});
        }
        self.terminal.print("\r\n", .{});
    }

    self.terminal.resetStyle();
    self.terminal.flush();
}

pub fn getEdge(self: *const Self, edge: Edge) []const u8 {
    return if (self.ascii) switch (edge) {
        .left => "|",
        .right => "|",
        .top => "-",
        .bottom => "-",
        .top_left => ",",
        .top_right => ",",
        .bottom_left => "'",
        .bottom_right => "'",
    } else switch (edge) {
        .left => "▌",
        .right => "▐",
        .top => "🬂",
        .bottom => "🬭",
        .top_left => "🬕",
        .top_right => "🬨",
        .bottom_left => "🬲",
        .bottom_right => "🬷",
    };
}
