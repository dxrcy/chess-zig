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

const PIECE_LENGTH: usize = 3;
const PIECE_HEIGHT: usize = 3;

const PADDING_LEFT: usize = 3;
const PADDING_RIGHT: usize = 3;
const PADDING_TOP: usize = 1;
const PADDING_BOTTOM: usize = 1;

const CELL_LENGTH: usize = PIECE_LENGTH + PADDING_LEFT + PADDING_RIGHT;
const CELL_HEIGHT: usize = PIECE_HEIGHT + PADDING_TOP + PADDING_BOTTOM;

const edges = struct {
    const LEFT = "▌";
    const RIGHT = "▐";
    const TOP = "🬂";
    const BOTTOM = "🬭";
    const TOP_LEFT = "🬕";
    const TOP_RIGHT = "🬨";
    const BOTTOM_LEFT = "🬲";
    const BOTTOM_RIGHT = "🬷";
};

pub fn new() Self {
    return Self{
        .terminal = Terminal.new(),
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
    self.terminal.setCursorPosition(1, 1);

    for (0..Board.SIZE) |row| {
        for (0..CELL_HEIGHT) |cell_line| {
            for (0..Board.SIZE) |col| {
                const PIECE_START = PADDING_TOP;
                const PIECE_END = PADDING_TOP + PIECE_LENGTH - 1;

                const position = Position{ .row = row, .col = col };

                self.setColor(state, position);

                if (cell_line < PIECE_START or cell_line > PIECE_END) {
                    if (cell_line == 0) {
                        self.printEmptyCellLine(state, position, .top);
                    } else if (cell_line == CELL_HEIGHT - 1) {
                        self.printEmptyCellLine(state, position, .bottom);
                    } else {
                        self.printEmptyCellLine(state, position, .middle);
                    }
                    continue;
                }

                const piece = state.board.get(row, col) orelse {
                    self.printEmptyCellLine(state, position, .middle);
                    continue;
                };

                const piece_line = cell_line - PIECE_START;
                const string = piece.string()[piece_line * PIECE_LENGTH ..][0..PIECE_LENGTH];

                self.printSide(state, position, .left);
                self.terminal.print("{s}", .{string});
                self.printSide(state, position, .right);
            }

            self.terminal.print("\r\n", .{});
        }
    }

    self.terminal.resetStyle();
    self.terminal.flush();
}

fn printEmptyCellLine(
    self: *Self,
    state: *const State,
    position: Position,
    side: enum { top, bottom, middle },
) void {
    if (side == .middle) {
        self.printSide(state, position, .left);
        self.terminal.print(" " ** PIECE_LENGTH, .{});
        self.printSide(state, position, .right);
        return;
    }

    const string =
        if (!position.eql(state.cursor))
            " " ** CELL_LENGTH
        else if (side == .top)
            edges.TOP_LEFT ++
                edges.TOP ** (CELL_LENGTH - 2) ++
                edges.TOP_RIGHT
        else
            edges.BOTTOM_LEFT ++
                edges.BOTTOM ** (CELL_LENGTH - 2) ++
                edges.BOTTOM_RIGHT;

    self.terminal.print("{s}", .{string});
}

fn printSide(
    self: *Self,
    state: *const State,
    position: Position,
    side: enum { left, right },
) void {
    const string =
        if (!position.eql(state.cursor))
            (if (side == .left)
                " " ** PADDING_LEFT
            else
                " " ** PADDING_RIGHT)
        else
            (if (side == .left)
                edges.LEFT ++ " " ** (PADDING_LEFT - 1)
            else
                " " ** (PADDING_RIGHT - 1) ++ edges.RIGHT);

    self.terminal.print("{s}", .{string});
}

fn setColor(self: *Self, state: *const State, position: Position) void {
    const is_even = (position.row + position.col) % 2 == 0;

    const fg: Color =
        if (position.eql(state.cursor))
            (if (state.active == .black)
                .red
            else
                .blue)
        else if (is_even)
            .black
        else
            .white;

    const bg: Color =
        if (is_even)
            .white
        else
            .black;

    self.terminal.setStyle(.bold);
    self.terminal.setForeground(fg);
    self.terminal.setBackground(bg);
}
