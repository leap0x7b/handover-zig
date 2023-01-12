const std = @import("std");
const testing = std.testing;

pub const COLDBOOT: u64 = 0xc001b001;

pub const Tag = enum(u64) {
    Free = 0x00000000,
    Magic = COLDBOOT,
    Self = 0xa24f988d,
    Stack = 0xf65b391b,
    Kernel = 0xbfc71b20,
    Loader = 0xf1f80c26,
    File = 0xcbc36d3b,
    Rdsp = 0x8ef29c18,
    Fdt = 0xb628bbc1,
    Fb = 0xe2d5685,
    Cmdline = 0x435140c4,
    Reserved = 0xb8841d2d,
    End = 0xffffffff,
};

pub const Record = struct {
    tag: Tag,
    flags: u32,
    start: u64,
    size: u64,
    /// Originally unnamed
    tags: extern union {
        fb: extern struct {
            width: u16,
            height: u16,
            pitch: u16,
            format: Format,

            pub const Format = enum(u16) {
                RgbX8888 = 0x7451,
                BgrX8888 = 0xd040,
            };
        },
        file: extern struct {
            name: u32,
            meta: u32,
        },
        more: u64,
    },
};

pub const Payload = extern struct {
    const Self = @This();

    magic: u32,
    agent: u32,
    size: u32,
    count: u32,
    records: []Record,

    pub fn insert(self: *Self, index: usize, record: Record) void {
        var i: u32 = self.count;
        while (i > index) : (i -= 1)
            self.records[i] = self.records[i - 1];

        self.records[index] = record;
        self.count += 1;
    }

    pub fn remove(self: *Self, index: usize) void {
        var i: u32 = self.count;
        while (i < index) : (i += 1)
            self.records[i] = self.records[i + 1];

        self.count -= 1;
    }

    pub fn append(self: *Self, record: Record) void {
        if (record.size == 0)
            return;

        var i: u32 = 0;
        while (i < self.count) : (i += 1) {
            var other = &self.records[i];

            if (record.tag == other.tag and justAfter(record, *other) and mergable(record.tag)) {
                other.size += record.size;
                return;
            }

            if (record.tag == other.tag and justBefore(record, *other) and mergable(record.tag)) {
                other.start -= record.size;
                other.size += record.size;
                return;
            }

            if (overlap(record, *other)) {
                if (!mergable(record.tag)) {
                    var tmp = record;
                    record = *other;
                    (*other) = tmp;
                }

                var half_under = halfUnder(record, *other);
                var half_over = halfOver(record, *other);

                self.remove(i);

                if (half_under.size)
                    self.insert(i, half_under);

                if (half_over.size)
                    self.insert(i, half_over);

                return;
            }

            if (record.start < other.start) {
                self.insert(i, record);
                return;
            }
        }

        self.count += 1;
        self.records[self.count] = record;
    }

    pub fn str(self: *Self, offset: u32) []const u8 {
        return @intToPtr([]const u8, @ptrToInt(self) + offset);
    }
};

pub const Request = struct {
    tag: u32,
    flags: u32,
    more: u64,
};

pub fn mergable(tag: Tag) bool {
    return switch (tag) {
        .Free, .Loader, .Kernel, .Reserved => true,
        else => false,
    };
}

pub fn overlap(lhs: Record, rhs: Record) bool {
    return (lhs.start < rhs.start + rhs.size) and (rhs.start < lhs.start + lhs.size);
}

pub fn justBefore(lhs: Record, rhs: Record) bool {
    return lhs.start + lhs.size == rhs.start;
}

pub fn justAfter(lhs: Record, rhs: Record) bool {
    return lhs.start == rhs.start + rhs.size;
}

pub fn halfUnder(self: Record, other: Record) Record {
    if (overlap(self, other) and self.start < other.start) {
        return .{
            .tag = self.tag,
            .flags = 0,
            .start = self.start,
            .size = other.start - self.start,
            .tags = self.tags,
        };
    }
    return undefined;
}

pub fn halfOver(self: Record, other: Record) Record {
    if (overlap(self, other) and self.start + self.size < other.start + other.size) {
        return .{
            .tag = self.tag,
            .flags = 0,
            .start = other.start + other.size,
            .size = self.start + self.size - other.start - other.size,
            .tags = self.tags,
        };
    }
    return undefined;
}

test "docs" {
    // this is a dummy test function for docs generation
    // im too lazy to write actual tests
}

comptime {
    std.testing.refAllDecls(@This());
}
