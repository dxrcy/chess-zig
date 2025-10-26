const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const posix = std.posix;

const Board = @import("Board.zig");
const State = @import("State.zig");
const Ui = @import("Ui.zig");

pub fn main() !void {
    var ui = Ui.new();
    try ui.enter();
    // Restore terminal, if anything goes wrong
    errdefer ui.exit() catch unreachable;

    var state = State.new();

    var stdin = fs.File.stdin();

    while (true) {
        ui.render(&state);

        var buffer: [1]u8 = undefined;
        const bytes_read = try stdin.read(&buffer);
        if (bytes_read < 1) {
            break;
        }

        switch (buffer[0]) {
            0x03 => break,

            'h' => state.move(.left),
            'l' => state.move(.right),
            'k' => state.move(.up),
            'j' => state.move(.down),

            0x20 => {
                state.active = if (state.active == .black) .white else .black;
            },

            else => {},
        }
    }

    try ui.exit();
}
