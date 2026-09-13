const std = @import("std");
const Random = std.Random;
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const material = @import("material.zig");
const Material = material.Material;
const World = @import("world.zig").World;
const Camera = @import("camera.zig").Camera;

var random = Random.DefaultPrng.init(420);
pub const rand = random.random();

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();
    var world: World = try World.init(alloc);
    defer world.deinit();
    const camera = Camera.init(alloc, init.io);
    try fullWorld(&world);
    try camera.render(&world);
}

fn exampleFirst(world: *World) !void {
    const ground = try world.addMaterial(Material.initLambertian(Vec3{ 0.8, 0.8, 0.0 }));
    const center = try world.addMaterial(Material.initLambertian(Vec3{ 0.1, 0.2, 0.5 }));
    const left = try world.addMaterial(Material.initDielectric(1.5));
    const bubble = try world.addMaterial(Material.initDielectric(1.0 / 1.5));
    const right = try world.addMaterial(Material.initMetal(Vec3{ 0.8, 0.6, 0.2 }, 1.0));

    try world.drawSphere(.{ 0, -100.5, -1 }, 100, ground);
    try world.drawSphere(.{ 0, 0, -1.2 }, 0.5, center);
    try world.drawSphere(.{ -1, 0, -1 }, 0.5, left);
    try world.drawSphere(.{ -1, 0, -1 }, 0.4, bubble);
    try world.drawSphere(.{ 1, 0, -1 }, 0.5, right);
}

fn fullWorld(world: *World) !void {
    const ground = try world.addMaterial(Material.initLambertian(Vec3{ 0.5, 0.5, 0.5 }));
    try world.drawSphere(.{ 0, -1000, 0 }, 1000, ground);
    var a: i8 = -11;
    while (a < 11) : (a += 1) {
        var b: i8 = -11;
        while (b < 11) : (b += 1) {
            const choose_mat = rand.float(f64);
            const center = Vec3{ @as(f64, @floatFromInt(a)) + 0.9 * rand.float(f64), 0.2, b + 0.9 * rand.float(f64) };
            if (vec.length(&(center - Vec3{ 4, 0.2, 0 })) > 0.9) {
                if (choose_mat < 0.8) {
                    const albedo = Vec3{ rand.float(f64), rand.float(f64), rand.float(f64) };
                    const sphere_material = try world.addMaterial(Material.initLambertian(albedo));
                    try world.drawSphere(center, 0.2, sphere_material);
                } else if (choose_mat < 0.95) {
                    const albedo = vec.randomUnitVectorWithRange(0.5, 1);
                    const fuzz = rand.float(f64) * 0.5;
                    const sphere_material = try world.addMaterial(Material.initMetal(albedo, fuzz));
                    try world.drawSphere(center, 0.2, sphere_material);
                } else {
                    const sphere_material = try world.addMaterial(Material.initDielectric(1.5));
                    try world.drawSphere(center, 0.2, sphere_material);
                }
            }
        }
    }
    const material1 = try world.addMaterial(Material.initDielectric(1.5));
    try world.drawSphere(Vec3{ 0, 1, 0 }, 1.0, material1);

    const material2 = try world.addMaterial(Material.initLambertian(Vec3{ 0.4, 0.2, 0.1 }));
    try world.drawSphere(Vec3{ -4, 1, 0 }, 1.0, material2);

    const material3 = try world.addMaterial(Material.initMetal(Vec3{ 0.7, 0.6, 0.5 }, 0.0));
    try world.drawSphere(Vec3{ 4, 1, 0 }, 1.0, material3);
}
