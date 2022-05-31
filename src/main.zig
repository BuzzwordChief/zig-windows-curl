const std = @import("std");
const cURL = @cImport({
    @cInclude("curl/curl.h");
});


const ca_str = @embedFile("../curl-ca-bundle.crt");

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena_state.deinit();

    const allocator = arena_state.allocator();

    // global curl init, or fail
    if (cURL.curl_global_init(cURL.CURL_GLOBAL_ALL) != cURL.CURLE_OK)
        return error.CURLGlobalInitFailed;
    defer cURL.curl_global_cleanup();

    // curl easy handle init, or fail
    const handle = cURL.curl_easy_init() orelse return error.CURLHandleInitFailed;
    defer cURL.curl_easy_cleanup(handle);

    var response_buffer = std.ArrayList(u8).init(allocator);

    // superfluous when using an arena allocator, but
    // important if the allocator implementation changes
    defer response_buffer.deinit();



    // setup curl options
    var cpam : cURL.curl_blob = .{ .data = @intToPtr(*anyopaque, @ptrToInt(ca_str)), .len = ca_str.len, .flags = cURL.CURL_BLOB_COPY };
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_CAINFO_BLOB, &cpam) != cURL.CURLE_OK)
        return error.CouldNotSetCAINFO;
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_URL, "https://ziglang.org") != cURL.CURLE_OK)
        return error.CouldNotSetURL;
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_FOLLOWLOCATION, @as(c_long, 1)) != cURL.CURLE_OK)
        return error.CouldNotSetFollowLocation;

    // set write function callbacks
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_WRITEFUNCTION, writeToArrayListCallback) != cURL.CURLE_OK)
        return error.CouldNotSetWriteCallback;
    if (cURL.curl_easy_setopt(handle, cURL.CURLOPT_WRITEDATA, &response_buffer) != cURL.CURLE_OK)
        return error.CouldNotSetWriteCallback;

    // perform
    if (cURL.curl_easy_perform(handle) != cURL.CURLE_OK)
        return error.FailedToPerformRequest;

    // Print result
    std.log.info("Got response of {d} bytes", .{response_buffer.items.len});
    std.log.info("Writing result.html...", .{});
    try std.fs.cwd().writeFile("result.html", response_buffer.items);
    std.log.info("...Done!", .{});
}

fn writeToArrayListCallback(data: *anyopaque, size: c_uint, nmemb: c_uint, user_data: *anyopaque) callconv(.C) c_uint {
    var buffer = @intToPtr(*std.ArrayList(u8), @ptrToInt(user_data));
    var typed_data = @intToPtr([*]u8, @ptrToInt(data));
    buffer.appendSlice(typed_data[0 .. nmemb * size]) catch return 0;
    return nmemb * size;
}
