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
frames: [2]Frame,
current_frame: u1,
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
        .frames = [1]Frame{Frame.new(.{})} ** 2,
        .current_frame = 0,
        .ascii = ascii,
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
    const frame = self.getForeFrame();

    for (0..Board.SIZE) |row| {
        for (0..Board.SIZE) |col| {
            const is_even = (row + col) % 2 == 0;
            const bg: Color = if (is_even) .black else .white;

            for (0..dims.CELL_HEIGHT) |y| {
                for (0..dims.CELL_WIDTH) |x| {
                    frame.set(
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

                        frame.set(
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
        frame.set(
            state.cursor.row * dims.CELL_HEIGHT,
            state.cursor.col * dims.CELL_WIDTH + x,
            .{ .fg = cursor_fg, .char = self.getEdge(.top) },
        );
    }
    for (1..dims.CELL_WIDTH - 1) |x| {
        frame.set(
            state.cursor.row * dims.CELL_HEIGHT + dims.CELL_HEIGHT - 1,
            state.cursor.col * dims.CELL_WIDTH + x,
            .{ .fg = cursor_fg, .char = self.getEdge(.bottom) },
        );
    }
    for (1..dims.CELL_HEIGHT - 1) |y| {
        frame.set(
            state.cursor.row * dims.CELL_HEIGHT + y,
            state.cursor.col * dims.CELL_WIDTH,
            .{ .fg = cursor_fg, .char = self.getEdge(.left) },
        );
    }
    for (1..dims.CELL_HEIGHT - 1) |y| {
        frame.set(
            state.cursor.row * dims.CELL_HEIGHT + y,
            state.cursor.col * dims.CELL_WIDTH + dims.CELL_WIDTH - 1,
            .{ .fg = cursor_fg, .char = self.getEdge(.right) },
        );
    }
    frame.set(
        state.cursor.row * dims.CELL_HEIGHT,
        state.cursor.col * dims.CELL_WIDTH,
        .{ .fg = cursor_fg, .char = self.getEdge(.top_left) },
    );
    frame.set(
        state.cursor.row * dims.CELL_HEIGHT,
        state.cursor.col * dims.CELL_WIDTH + dims.CELL_WIDTH - 1,
        .{ .fg = cursor_fg, .char = self.getEdge(.top_right) },
    );
    frame.set(
        state.cursor.row * dims.CELL_HEIGHT + dims.CELL_HEIGHT - 1,
        state.cursor.col * dims.CELL_WIDTH,
        .{ .fg = cursor_fg, .char = self.getEdge(.bottom_left) },
    );
    frame.set(
        state.cursor.row * dims.CELL_HEIGHT + dims.CELL_HEIGHT - 1,
        state.cursor.col * dims.CELL_WIDTH + dims.CELL_WIDTH - 1,
        .{ .fg = cursor_fg, .char = self.getEdge(.bottom_right) },
    );
}

pub fn draw(self: *Self) void {
    // TODO: Ideally remove this initial call after positioning is optimized
    self.terminal.setCursorPosition(1, 1);

    for (0..Frame.HEIGHT) |y| {
        for (0..Frame.WIDTH) |x| {
            const cell_fore = self.getForeFrame().get(y, x);
            const cell_back = self.getBackFrame().get(y, x);

            if (cell_back.eql(cell_fore.*)) {
                continue;
            }

            // PERF: Don't move if redundant
            // If previous (left) cell printed, it already moved the cursor for
            // to cell
            self.terminal.setCursorPosition(@intCast(y + 1), @intCast(x + 1));

            // PERF: Only reset/set attributes if necessary
            // (if any style changed, have to re-print character regardless)

            self.terminal.resetStyle();
            if (cell_fore.bold) {
                self.terminal.setStyle(.bold);
            }
            self.terminal.setForeground(cell_fore.fg);
            self.terminal.setBackground(cell_fore.bg);

            self.terminal.print("{u}", .{cell_fore.char});

            cell_back.* = cell_fore.*;
        }
    }

    self.terminal.resetStyle();
    self.terminal.flush();

    self.swapFrames();
}

pub fn getForeFrame(self: *Self) *Frame {
    return &self.frames[self.current_frame];
}
pub fn getBackFrame(self: *Self) *Frame {
    assert(@TypeOf(self.current_frame) == u1);
    return &self.frames[self.current_frame +% 1];
}
pub fn swapFrames(self: *Self) void {
    assert(@TypeOf(self.current_frame) == u1);
    self.current_frame +%= 1;
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
