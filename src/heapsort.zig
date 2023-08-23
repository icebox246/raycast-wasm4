// author: icebox246
// original implementation: https://en.wikipedia.org/wiki/Heapsort
const std = @import("std");

test "Sorting array of u8 with heapsort" {
    var arr = [_]u8{ 5, 3, 4, 2, 8, 1 };

    std.debug.print("arr:        {any}\n", .{arr});

    heapsort(u8, (struct {
        fn lessThan(a: *const u8, b: *const u8) bool {
            return a.* < b.*;
        }
    }).lessThan, &arr);

    std.debug.print("arr sorted: {any}\n", .{arr});

    const expected = [_]u8{ 1, 2, 3, 4, 5, 8 };

    try std.testing.expectEqual(arr, expected);
}

test "Sort empty array" {
    heapsort(u8, (struct {
        fn lessThan(a: *const u8, b: *const u8) bool {
            return a.* < b.*;
        }
    }).lessThan, &.{});
}

pub fn LessThan(comptime T: type) type {
    return fn (*const T, *const T) bool;
}

pub fn heapsort(comptime T: type, cmp: LessThan(T), arr: []T) void {
    if (arr.len == 0) return;

    heapify(T, cmp, arr);

    var s = arr[0..arr.len];
    while (s.len >= 1) {
        swap(T, &s[0], &s[s.len - 1]);
        s = s[0 .. s.len - 1];
        siftDown(T, cmp, s, 0);
    }
}

fn heapify(comptime T: type, cmp: LessThan(T), arr: []T) void {
    var v = parent(arr.len - 1);

    while (v >= 0) : (v -= 1) {
        siftDown(T, cmp, arr, v);
        if (v == 0) break;
    }
}

fn siftDown(comptime T: type, cmp: LessThan(T), arr: []T, v: usize) void {
    var root = v;
    while (leftChild(root) < arr.len) {
        const child = leftChild(root);
        var cand = root;
        if (cmp(&arr[cand], &arr[child]))
            cand = child;

        if (child + 1 < arr.len and cmp(&arr[cand], &arr[child + 1]))
            cand = child + 1;

        if (cand == root) {
            return;
        } else {
            swap(T, &arr[root], &arr[cand]);
            root = cand;
        }
    }
}

fn swap(comptime T: type, a: *T, b: *T) void {
    const c = a.*;
    a.* = b.*;
    b.* = c;
}

fn parent(x: usize) usize {
    return (x - 1) / 2;
}

fn leftChild(x: usize) usize {
    return x * 2 + 1;
}

fn rightChild(x: usize) usize {
    return x * 2 + 2;
}
