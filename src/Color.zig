const Vec3 = @import("vec.zig").Vec3;

pub const Self = @This();
r: u8,
g: u8,
b: u8,

pub const green = Self{ .r = 0, .g = 255, .b = 0 };
pub const red = Self{ .r = 255, .g = 0, .b = 0 };
pub const blue = Self{ .r = 0, .g = 0, .b = 255 };
pub const white = Self{ .r = 255, .g = 255, .b = 255 };
pub const black = Self{ .r = 0, .g = 0, .b = 0 };

pub fn bytes(self: Self) [3]u8 {
    return .{ self.r, self.g, self.b };
}

pub fn init(r: f64, g: f64, b: f64) Self {
    fromVec(Vec3{ r, g, b });
}

pub fn fromVec(vec: Vec3) Self {
    const gammaVec = Vec3{
        linearToGamma(vec[0]),
        linearToGamma(vec[1]),
        linearToGamma(vec[2]),
    };

    const color_vec: @Vector(3, u8) = @trunc(@Vector(3, f64){ 256, 256, 256 } * clampVec(gammaVec));
    return Self{
        .r = color_vec[0],
        .g = color_vec[1],
        .b = color_vec[2],
    };
}

fn linearToGamma(n: f64) f64 {
    if (n > 0) {
        return @sqrt(n);
    }

    return 0;
}

fn clampVec(vec: Vec3) Vec3 {
    return Vec3{
        clamp(vec[0]),
        clamp(vec[1]),
        clamp(vec[2]),
    };
}

fn clamp(x: f64) f64 {
    return if (x < 0) 0 else if (x > 0.999) 0.999 else x;
}
