const Self = @This();

const std = @import("std");
const assert = std.debug.assert;
const posix = std.posix;

const State = @import("State.zig");
const Board = State.Board;
const Piece = State.Board.Piece;
const Position = State.Position;

const Terminal = @import("Terminal.zig");
const Color = Terminal.Color;

const Frame = @import("Frame.zig");

terminal: Terminal,
frame: Frame,
ascii: bool,

pub const dims = struct {
    pub const CELL_WIDTH: usize = Piece.WIDTH + PADDING_LEFT + PADDING_RIGHT;
    pub const CELL_HEIGHT: usize = Piece.HEIGHT + PADDING_TOP + PADDING_BOTTOM;

    const PADDING_LEFT: usize = 3;
    const PADDING_RIGHT: usize = 3;
    const PADDING_TOP: usize = 1;
    const PADDING_BOTTOM: usize = 1;
};

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
    return Self{
        .terminal = Terminal.new(),
        .ascii = ascii,
        .frame = Frame.new(.{}),
    };
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
    for (0..Board.SIZE) |row| {
        for (0..Board.SIZE) |col| {
            const is_even = (row + col) % 2 == 0;
            const bg: Color = if (is_even) .black else .white;

            for (0..dims.CELL_HEIGHT) |y| {
                for (0..dims.CELL_WIDTH) |x| {
                    self.frame.set(
                        row * dims.CELL_HEIGHT + y,
                        col * dims.CELL_WIDTH + x,
                        .{ .char = ' ', .bg = bg },
                    );
                }
            }

            if (state.board.get(row, col)) |piece| {
                const string = piece.string();

                for (0..Piece.HEIGHT) |y| {
                    for (0..Piece.WIDTH) |x| {
                        const char = string[y * Piece.HEIGHT + x];

                        self.frame.set(
                            row * dims.CELL_HEIGHT + y + dims.PADDING_TOP,
                            col * dims.CELL_WIDTH + x + dims.PADDING_LEFT,
                            .{ .char = char, .fg = .green, .bold = true },
                        );
                    }
                }
            }
        }
    }

    const cursor_fg: Color = if (state.active == .white) .blue else .red;

    for (1..dims.CELL_WIDTH - 1) |x| {
        self.frame.set(
            state.cursor.row * dims.CELL_HEIGHT,
            state.cursor.col * dims.CELL_WIDTH + x,
            .{ .fg = cursor_fg, .char = self.getEdge(.top) },
        );
    }
    for (1..dims.CELL_WIDTH - 1) |x| {
        self.frame.set(
            state.cursor.row * dims.CELL_HEIGHT + dims.CELL_HEIGHT - 1,
            state.cursor.col * dims.CELL_WIDTH + x,
            .{ .fg = cursor_fg, .char = self.getEdge(.bottom) },
        );
    }
    for (1..dims.CELL_HEIGHT - 1) |y| {
        self.frame.set(
            state.cursor.row * dims.CELL_HEIGHT + y,
            state.cursor.col * dims.CELL_WIDTH,
            .{ .fg = cursor_fg, .char = self.getEdge(.left) },
        );
    }
    for (1..dims.CELL_HEIGHT - 1) |y| {
        self.frame.set(
            state.cursor.row * dims.CELL_HEIGHT + y,
            state.cursor.col * dims.CELL_WIDTH + dims.CELL_WIDTH - 1,
            .{ .fg = cursor_fg, .char = self.getEdge(.right) },
        );
    }
    self.frame.set(
        state.cursor.row * dims.CELL_HEIGHT,
        state.cursor.col * dims.CELL_WIDTH,
        .{ .fg = cursor_fg, .char = self.getEdge(.top_left) },
    );
    self.frame.set(
        state.cursor.row * dims.CELL_HEIGHT,
        state.cursor.col * dims.CELL_WIDTH + dims.CELL_WIDTH - 1,
        .{ .fg = cursor_fg, .char = self.getEdge(.top_right) },
    );
    self.frame.set(
        state.cursor.row * dims.CELL_HEIGHT + dims.CELL_HEIGHT - 1,
        state.cursor.col * dims.CELL_WIDTH,
        .{ .fg = cursor_fg, .char = self.getEdge(.bottom_left) },
    );
    self.frame.set(
        state.cursor.row * dims.CELL_HEIGHT + dims.CELL_HEIGHT - 1,
        state.cursor.col * dims.CELL_WIDTH + dims.CELL_WIDTH - 1,
        .{ .fg = cursor_fg, .char = self.getEdge(.bottom_right) },
    );
}

pub fn draw(self: *Self) void {
    self.terminal.setCursorPosition(1, 1);

    // PERF: Only update cells which changed from last frame
    for (0..Frame.HEIGHT) |y| {
        for (0..Frame.WIDTH) |x| {
            const cell = self.frame.get(y, x);
            // PERF: Only set attributes if changed from previous cell
            self.terminal.resetStyle();
            if (cell.bold) {
                self.terminal.setStyle(.bold);
            }
            self.terminal.setForeground(cell.fg);
            self.terminal.setBackground(cell.bg);
            self.terminal.print("{u}", .{cell.char});
        }
        self.terminal.print("\r\n", .{});
    }

    self.terminal.resetStyle();
    self.terminal.flush();
}

pub fn getEdge(self: *const Self, edge: Edge) u21 {
    return if (self.ascii) switch (edge) {
        .left => '|',
        .right => '|',
        .top => '-',
        .bottom => '-',
        .top_left => ',',
        .top_right => ',',
        .bottom_left => '\'',
        .bottom_right => '\'',
    } else switch (edge) {
        .left => '▌',
        .right => '▐',
        .top => '🬂',
        .bottom => '🬭',
        .top_left => '🬕',
        .top_right => '🬨',
        .bottom_left => '🬲',
        .bottom_right => '🬷',
    };
}
