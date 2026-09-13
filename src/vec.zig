const rand = @import("main.zig").rand;
pub const Vec3 = @Vector(3, f64);
pub const zero = Vec3{ 0.0, 0.0, 0.0 };
pub const one = Vec3{ 1.0, 1.0, 1.0 };
pub const two = Vec3{ 2.0, 2.0, 2.0 };
pub const half = Vec3{ 0.5, 0.5, 0.5 };

pub fn length(vec: *const Vec3) f64 {
    return @sqrt(dot(vec, vec));
}

pub fn dot(lhs: *const Vec3, rhs: *const Vec3) f64 {
    return @reduce(.Add, lhs.* * rhs.*);
}

pub fn unitVector(vec: *const Vec3) Vec3 {
    return vec.* / @as(Vec3, @splat(length(vec)));
}

pub fn cross(lhs: *const Vec3, rhs: *const Vec3) Vec3 {
    return Vec3{
        lhs[1] * rhs[2] - lhs[2] * rhs[1],
        lhs[2] * rhs[0] - lhs[0] * rhs[2],
        lhs[0] * rhs[1] - lhs[1] * rhs[0],
    };
}

pub fn scale(lhs: *const Vec3, s: f64) Vec3 {
    return Vec3{ lhs[0] * s, lhs[1] * s, lhs[2] * s };
}

pub fn equals(lhs: *const Vec3, rhs: *const Vec3) bool {
    return @reduce(.And, lhs == rhs);
}

pub fn splat(n: f64) Vec3 {
    return @splat(n);
}

pub fn nearZero(vec: *const Vec3) bool {
    const s = splat(1e-8);
    return @reduce(.And, @abs(vec.*) < s);
}

pub fn reflect(lhs: *const Vec3, rhs: *const Vec3) Vec3 {
    return lhs.* - splat(2) * splat(dot(lhs, rhs)) * rhs.*;
}

pub fn refract(lhs: *const Vec3, rhs: *const Vec3, etai_over_etat: f64) Vec3 {
    const cos_theta = @min(dot(&(-lhs.*), rhs), 1.0);
    const r_out_perp = splat(etai_over_etat) * @mulAdd(Vec3, splat(cos_theta), rhs.*, lhs.*);
    return @mulAdd(Vec3, splat(-@sqrt(@abs(1.0 - dot(&r_out_perp, &r_out_perp)))), rhs.*, r_out_perp);
}

pub fn randomUnitVectorWithRange(min: f64, max: f64) Vec3 {
    while (true) {
        const p = Vec3{
            @mulAdd(f64, rand.float(f64), (max - min), min),
            @mulAdd(f64, rand.float(f64), (max - min), min),
            @mulAdd(f64, rand.float(f64), (max - min), min),
        };
        const len = dot(&p, &p);
        if (1e-160 < len and len <= 1)
            return p / splat(@sqrt(len));
    }
}

pub fn randomInUnitDisk(min: f64, max: f64) Vec3 {
    while (true) {
        const p = Vec3{
            @mulAdd(f64, rand.float(f64), (max - min), min),
            @mulAdd(f64, rand.float(f64), (max - min), min),
            0,
        };

        if (dot(&p, &p) < 1) return p;
    }
}
