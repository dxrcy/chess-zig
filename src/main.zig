const std = @import("std");
const assert = std.debug.assert;
const fs = std.fs;
const posix = std.posix;

const Board = @import("Board.zig");
const Ui = @import("Ui.zig");

pub fn main() !void {
    var ui = Ui.new();
    try ui.enter();
    // Restore terminal, if anything goes wrong
    errdefer ui.exit() catch unreachable;

    var stdin = fs.File.stdin();

    const board = Board.new();

    while (true) {
        ui.render(&board);

        var buffer: [1]u8 = undefined;
        const bytes_read = try stdin.read(&buffer);
        if (bytes_read < 1) {
            break;
        }

        switch (buffer[0]) {
            0x03 => break,

            'h' => ui.move(.left),
            'l' => ui.move(.right),
            'k' => ui.move(.up),
            'j' => ui.move(.down),

            0x20 => {
                ui.active = if (ui.active == .black) .white else .black;
            },

            else => {},
        }
    }

    try ui.exit();
}
