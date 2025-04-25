const std = @import("std");

pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,
    fatal,

    pub fn text(comptime self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
            .fatal => "FATAL",
        };
    }
};

fn getLogInfo(debug_info: *std.debug.SelfInfo, address: usize, stream: anytype) bool {
    const mod = debug_info.getModuleForAddress(address) catch return false;
    const sym = mod.getSymbolAtAddress(debug_info.allocator, address) catch return false;
    defer sym.deinit(debug_info.allocator);

    if (sym.line_info(debug_info.allocator)) |li| {
        if (std.mem.indexOf(u8, li.file_name, "std" ++ std.fs.path.sep_str ++ "log.zig") != null) return false;
        stream.print("|{s} {d}:{d}| ", .{ li.file_name, li.line, li.column });
        return true;
    }
    return false;
}

pub fn logFn(comptime level: LogLevel, comptime scope: @Type(.enum_literal), comptime format: []const u8, args: anytype) void {
    const debug_info = std.debug.getSelfDebugInfo() catch unreachable;
    const context: std.debug.ThreadContext = undefined;
    _ = std.debug.getContext(@constCast(&context));
    var it = blk: {
        break :blk std.debug.StackIterator.initWithContext(null, debug_info, @constCast(&context)) catch null;
    };
    defer it.deinit();

    while (it.next()) |return_address| {
        const addr = if (return_address == 0) return_address else return_address - 1;
        if (getLogInfo(debug_info, addr, std.io.getStdErr().writer())) break;
    }

    const scope_prefix = "{{" ++ @tagName(scope) ++ "}} ";
    const prefix = "[" ++ comptime level.text() ++ "] " ++ scope_prefix;

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();

    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format ++ "\n", args) catch {
        return;
    };
}

const fnType = fn (comptime level: LogLevel, comptime scope: @Type(.enum_literal), comptime format: []const u8, args: anytype) void;
pub const logStruct = struct {
    log_func: fnType,
    log_scope: @Type(.enum_literal),
    log_level: LogLevel,

    fn prelog(self: *const logStruct, lvl: LogLevel) bool {
        return (@intFromEnum(lvl) >= @intFromEnum(self.log_level));
    }

    pub fn debug(self: *const logStruct, comptime format: []const u8, args: anytype) void {
        const lvl: LogLevel = .debug;
        if (self.prelog(lvl) == false) {
            return;
        }
        self.log_func(lvl, self.log_scope, format, args);
    }

    pub fn info(self: *const logStruct, comptime format: []const u8, args: anytype) void {
        const lvl: LogLevel = .info;
        if (self.prelog(lvl) == false) {
            return;
        }
        self.log_func(lvl, self.log_scope, format, args);
    }

    pub fn warn(self: *const logStruct, comptime format: []const u8, args: anytype) void {
        const lvl: LogLevel = .warn;
        if (self.prelog(lvl) == false) {
            return;
        }
        self.log_func(lvl, self.log_scope, format, args);
    }

    pub fn err(self: *const logStruct, comptime format: []const u8, args: anytype) void {
        const lvl: LogLevel = .err;
        if (self.prelog(lvl) == false) {
            return;
        }
        self.log_func(lvl, self.log_scope, format, args);
    }

    pub fn fatal(self: *const logStruct, comptime format: []const u8, args: anytype) void {
        const lvl: LogLevel = .fatal;
        if (self.prelog(lvl) == false) {
            return;
        }
        self.log_func(lvl, self.log_scope, format, args);
    }
};

pub fn genLog(comptime level: LogLevel, comptime scope: @Type(.enum_literal), comptime func: fnType) logStruct {
    return .{
        .log_level = level,
        .log_scope = scope,
        .log_func = func,
    };
}

pub const log = genLog(.debug, .none, logFn);
