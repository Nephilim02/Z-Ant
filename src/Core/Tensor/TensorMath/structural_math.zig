const std = @import("std");
const Tensor = @import("tensor").Tensor; // Import Tensor type
const pkg_allocator = @import("pkgAllocator").allocator;
const TensorMathError = @import("errorHandler").TensorMathError;
const TensorError = @import("errorHandler").TensorError;

/// Resize the input tensor using interpolation.
/// Supports 'nearest', 'linear', and 'cubic' interpolation modes.
pub fn resize(comptime T: type, t: *Tensor(T), comptime mode: []const u8, scales: ?[]const f32, sizes: ?[]const usize, coordinate_transformation_mode: []const u8) !Tensor(T) {
    if (scales == null and sizes == null) {
        return TensorError.InvalidInput;
    }
    if (scales != null and sizes != null) {
        return TensorError.InvalidInput;
    }

    // Calculate output dimensions
    var output_shape = try t.allocator.alloc(usize, t.shape.len);
    errdefer t.allocator.free(output_shape);

    if (scales) |s| {
        if (s.len != t.shape.len) {
            return TensorError.InvalidInput;
        }
        for (0..t.shape.len) |i| {
            output_shape[i] = @intFromFloat(@floor(@as(f32, @floatFromInt(t.shape[i])) * s[i]));
        }
    } else if (sizes) |sz| {
        if (sz.len != t.shape.len) {
            return TensorError.InvalidInput;
        }
        @memcpy(output_shape, sz);
    }

    // Calculate total size of output tensor
    var total_size: usize = 1;
    for (output_shape) |dim| {
        total_size *= dim;
    }

    // Allocate memory for output data
    const output_data = try t.allocator.alloc(T, total_size);
    errdefer t.allocator.free(output_data);

    // Perform interpolation based on mode
    if (std.mem.eql(u8, mode, "nearest")) {
        try nearest_interpolation(T, t, output_data, output_shape, coordinate_transformation_mode);
    } else if (std.mem.eql(u8, mode, "linear")) {
        try linear_interpolation(T, t, output_data, output_shape, coordinate_transformation_mode);
    } else if (std.mem.eql(u8, mode, "cubic")) {
        try cubic_interpolation(T, t, output_data, output_shape, coordinate_transformation_mode);
    } else {
        return TensorError.UnsupportedMode;
    }

    return Tensor(T){
        .data = output_data,
        .shape = output_shape,
        .size = total_size,
        .allocator = t.allocator,
    };
}

fn nearest_interpolation(comptime T: type, self: *Tensor(T), output_data: []T, output_shape: []usize, coordinate_transformation_mode: []const u8) !void {
    const input_strides = try self.getStrides();
    defer self.allocator.free(input_strides);
    const output_strides = try self.allocator.alloc(usize, output_shape.len);
    defer self.allocator.free(output_strides);

    // Calculate output strides
    var stride: usize = 1;
    var idx: usize = output_shape.len;
    while (idx > 0) {
        idx -= 1;
        output_strides[idx] = stride;
        stride *= output_shape[idx];
    }

    var output_indices = try self.allocator.alloc(usize, output_shape.len);
    defer self.allocator.free(output_indices);
    @memset(output_indices, 0);

    var done = false;
    while (!done) {
        var output_idx: usize = 0;
        var input_idx: usize = 0;

        for (0..output_shape.len) |i| {
            const scale = @as(f32, @floatFromInt(output_shape[i])) / @as(f32, @floatFromInt(self.shape[i]));
            var input_pos: f32 = undefined;

            if (std.mem.eql(u8, coordinate_transformation_mode, "half_pixel")) {
                input_pos = (@as(f32, @floatFromInt(output_indices[i])) + 0.5) / scale - 0.5;
            } else if (std.mem.eql(u8, coordinate_transformation_mode, "align_corners")) {
                input_pos = @as(f32, @floatFromInt(output_indices[i])) * @as(f32, @floatFromInt(self.shape[i] - 1)) / @as(f32, @floatFromInt(output_shape[i] - 1));
            } else { // asymmetric
                input_pos = @as(f32, @floatFromInt(output_indices[i])) / scale;
            }

            const input_idx_i = @as(i32, @intFromFloat(@round(input_pos)));
            const clamped_idx = @min(@max(input_idx_i, 0), @as(i32, @intCast(self.shape[i] - 1)));
            input_idx += @as(usize, @intCast(clamped_idx)) * input_strides[i];
            output_idx += output_indices[i] * output_strides[i];
        }

        output_data[output_idx] = self.data[input_idx];

        // Increment indices
        done = true;
        for (0..output_shape.len) |i| {
            output_indices[output_shape.len - 1 - i] += 1;
            if (output_indices[output_shape.len - 1 - i] < output_shape[output_shape.len - 1 - i]) {
                done = false;
                break;
            }
            output_indices[output_shape.len - 1 - i] = 0;
        }
    }
}

fn linear_interpolation(comptime T: type, self: *Tensor(T), output_data: []T, output_shape: []usize, coordinate_transformation_mode: []const u8) !void {
    // For now, implement only for 1D and 2D tensors
    if (self.shape.len > 2) return TensorError.UnsupportedDimension;

    const input_strides = try self.getStrides();
    defer self.allocator.free(input_strides);

    var output_indices = try self.allocator.alloc(usize, output_shape.len);
    defer self.allocator.free(output_indices);
    @memset(output_indices, 0);

    var done = false;
    while (!done) {
        var output_idx: usize = 0;
        if (output_shape.len == 1) {
            output_idx = output_indices[0];
        } else {
            output_idx = output_indices[0] * output_shape[1] + output_indices[1];
        }

        // Calculate interpolation coordinates
        var x: f32 = undefined;
        if (std.mem.eql(u8, coordinate_transformation_mode, "half_pixel")) {
            x = (@as(f32, @floatFromInt(output_indices[0])) + 0.5) * @as(f32, @floatFromInt(self.shape[0])) / @as(f32, @floatFromInt(output_shape[0])) - 0.5;
        } else if (std.mem.eql(u8, coordinate_transformation_mode, "align_corners")) {
            x = @as(f32, @floatFromInt(output_indices[0])) * @as(f32, @floatFromInt(self.shape[0] - 1)) / @as(f32, @floatFromInt(output_shape[0] - 1));
        } else { // asymmetric
            x = @as(f32, @floatFromInt(output_indices[0])) * @as(f32, @floatFromInt(self.shape[0])) / @as(f32, @floatFromInt(output_shape[0]));
        }

        const x_floor = @floor(x);
        const x0 = @as(usize, @intFromFloat(@max(0, x_floor)));
        const x1 = @min(x0 + 1, self.shape[0] - 1);
        const dx = x - x_floor;

        if (self.shape.len == 1) {
            const v0 = @as(f32, @floatFromInt(@as(i32, @intCast(self.data[x0]))));
            const v1 = @as(f32, @floatFromInt(@as(i32, @intCast(self.data[x1]))));
            const interpolated = v0 * (1 - dx) + v1 * dx;
            output_data[output_idx] = @as(T, @intFromFloat(@round(interpolated)));
        } else {
            var y: f32 = undefined;
            if (std.mem.eql(u8, coordinate_transformation_mode, "half_pixel")) {
                y = (@as(f32, @floatFromInt(output_indices[1])) + 0.5) * @as(f32, @floatFromInt(self.shape[1])) / @as(f32, @floatFromInt(output_shape[1])) - 0.5;
            } else if (std.mem.eql(u8, coordinate_transformation_mode, "align_corners")) {
                y = @as(f32, @floatFromInt(output_indices[1])) * @as(f32, @floatFromInt(self.shape[1] - 1)) / @as(f32, @floatFromInt(output_shape[1] - 1));
            } else { // asymmetric
                y = @as(f32, @floatFromInt(output_indices[1])) * @as(f32, @floatFromInt(self.shape[1])) / @as(f32, @floatFromInt(output_shape[1]));
            }

            const y_floor = @floor(y);
            const y0 = @as(usize, @intFromFloat(@max(0, y_floor)));
            const y1 = @min(y0 + 1, self.shape[1] - 1);
            const dy = y - y_floor;

            const v00 = @as(f32, @floatFromInt(@as(i32, @intCast(self.data[x0 * self.shape[1] + y0]))));
            const v01 = @as(f32, @floatFromInt(@as(i32, @intCast(self.data[x0 * self.shape[1] + y1]))));
            const v10 = @as(f32, @floatFromInt(@as(i32, @intCast(self.data[x1 * self.shape[1] + y0]))));
            const v11 = @as(f32, @floatFromInt(@as(i32, @intCast(self.data[x1 * self.shape[1] + y1]))));

            const tmp1 = v00 * (1 - dx) * (1 - dy);
            const tmp2 = v01 * (1 - dx) * dy;
            const tmp3 = v10 * dx * (1 - dy);
            const tmp4 = v11 * dx * dy;

            const interpolated = tmp1 + tmp2 + tmp3 + tmp4;
            output_data[output_idx] = @as(T, @intFromFloat(@round(interpolated)));
        }

        // Increment indices
        done = true;
        for (0..output_shape.len) |i| {
            output_indices[output_shape.len - 1 - i] += 1;
            if (output_indices[output_shape.len - 1 - i] < output_shape[output_shape.len - 1 - i]) {
                done = false;
                break;
            }
            output_indices[output_shape.len - 1 - i] = 0;
        }
    }
}

fn cubic_interpolation(comptime T: type, self: *Tensor(T), output_data: []T, output_shape: []usize, coordinate_transformation_mode: []const u8) !void {
    // For simplicity, implement only for 1D tensors initially
    if (self.shape.len != 1) return TensorError.UnsupportedDimension;

    var output_idx: usize = 0;
    while (output_idx < output_shape[0]) : (output_idx += 1) {
        var x: f32 = undefined;
        if (std.mem.eql(u8, coordinate_transformation_mode, "half_pixel")) {
            x = (@as(f32, @floatFromInt(output_idx)) + 0.5) * @as(f32, @floatFromInt(self.shape[0])) / @as(f32, @floatFromInt(output_shape[0])) - 0.5;
        } else if (std.mem.eql(u8, coordinate_transformation_mode, "align_corners")) {
            x = @as(f32, @floatFromInt(output_idx)) * @as(f32, @floatFromInt(self.shape[0] - 1)) / @as(f32, @floatFromInt(output_shape[0] - 1));
        } else { // asymmetric
            x = @as(f32, @floatFromInt(output_idx)) * @as(f32, @floatFromInt(self.shape[0])) / @as(f32, @floatFromInt(output_shape[0]));
        }

        const x0 = @as(i32, @intFromFloat(@floor(x)));
        const dx = x - @as(f32, @floatFromInt(x0));

        var sum: f32 = 0;
        var weight_sum: f32 = 0;

        var i: i32 = -1;
        while (i < 3) : (i += 1) {
            const idx = x0 + i;
            if (idx >= 0 and idx < @as(i32, @intCast(self.shape[0]))) {
                const w = cubic_weight(dx - @as(f32, @floatFromInt(i)));
                sum += @as(f32, @floatFromInt(@as(i32, @intCast(self.data[@as(usize, @intCast(idx))])))) * w;
                weight_sum += w;
            }
        }

        output_data[output_idx] = @as(T, @intFromFloat(@round(sum / weight_sum)));
    }
}

fn cubic_weight(x: f32) f32 {
    const a = -0.75;
    const abs_x = @abs(x);
    if (abs_x <= 1) {
        return ((a + 2) * abs_x - (a + 3)) * abs_x * abs_x + 1;
    } else if (abs_x < 2) {
        return ((a * abs_x - 5 * a) * abs_x + 8 * a) * abs_x - 4 * a;
    }
    return 0;
}

/// Concatenates a list of tensors into a single tensor along the specified axis.
/// All input tensors must have the same shape, except for the size of the concatenation axis.
///
/// Parameters:
///     allocator - The memory allocator to use for the new tensor.
///     tensors - An array of tensors to concatenate.
///     axis - The axis along which to concatenate. Negative values count dimensions from the back.
///
/// Returns:
///     A new tensor resulting from concatenation.
///
/// Errors:
///     - TensorError.EmptyTensorList
///     - TensorError.AxisOutOfBounds
///     - TensorError.MismatchedRank
///     - TensorError.MismatchedShape
pub fn concatenate(comptime T: type, allocator: *std.mem.Allocator, tensors: []Tensor(T), axis: isize) !Tensor(T) {
    // Ensure there is at least one tensor to concatenate
    if (tensors.len == 0) return TensorError.EmptyTensorList;

    // Determine the rank (number of dimensions) from the first tensor
    const rank = tensors[0].shape.len;

    var concat_axis = axis;
    if (concat_axis < 0) {
        concat_axis += @as(isize, @intCast(rank));
    }

    if (concat_axis < 0 or concat_axis >= @as(isize, @intCast(rank))) {
        return TensorError.AxisOutOfBounds;
    }

    const concat_axis_usize = @as(usize, @intCast(concat_axis));

    // Validate that all tensors have the same rank and matching shapes except along the concatenation axis
    for (tensors) |tensor| {
        if (tensor.shape.len != rank) {
            return TensorError.MismatchedRank;
        }
        for (0..rank) |d| {
            if (d != concat_axis_usize and tensor.shape[d] != tensors[0].shape[d]) {
                return TensorError.MismatchedShape;
            }
        }
    }

    // Calculate the new shape after concatenation
    var new_shape = try allocator.alloc(usize, rank);
    for (0..rank) |d| {
        if (d == concat_axis_usize) {
            var sum: usize = 0;
            for (tensors) |tensor| {
                sum += tensor.shape[d];
            }
            new_shape[d] = sum;
        } else {
            new_shape[d] = tensors[0].shape[d];
        }
    }

    // Calculate the total number of elements in the new tensor
    var total_size: usize = 1;
    for (new_shape) |dim| {
        total_size *= dim;
    }

    // Allocate memory for the new tensor's data
    var new_data = try allocator.alloc(T, total_size);

    // Calculate the number of slices based on the concatenation axis
    var num_slices: usize = 1;
    for (0..concat_axis_usize) |d| {
        num_slices *= new_shape[d];
    }

    // Calculate the slice size (number of elements to copy per concatenation dimension)
    var slice_size: usize = 1;
    if (concat_axis_usize + 1 < rank) {
        for ((concat_axis_usize + 1)..rank) |d| {
            slice_size *= new_shape[d];
        }
    } else {
        slice_size = 1;
    }

    // Initialize the offset for copying data into new_data
    var offset: usize = 0;

    // Iterate over each slice
    for (0..num_slices) |slice_idx| {
        for (tensors, 0..) |tensor, tensor_idx| {
            const concat_dim = tensor.shape[concat_axis_usize];
            const copy_size = concat_dim * slice_size;

            std.debug.print("\n  Copying Tensor {}: slice_idx={} concat_dim={} slice_size={} copy_size={} to new_data[{}..{}]", .{ tensor_idx, slice_idx, concat_dim, slice_size, copy_size, offset, offset + copy_size });

            // Calculate the start and end indices in the source tensor
            const src_start = slice_idx * concat_dim * slice_size;
            const src_end = src_start + copy_size;

            // Check bounds for the source tensor's data
            if (src_end > tensor.data.len) {
                std.debug.print("\n  Out of bounds error for tensor idx:{} src_end:{} tensor.data.len:{}", .{ tensor_idx, src_end, tensor.data.len });
                return TensorError.IndexOutOfBounds;
            }

            // Calculate the destination indices in new_data
            const dest_start = offset;
            const dest_end = offset + copy_size;

            // Check bounds for the new_data buffer
            if (dest_end > new_data.len) {
                std.debug.print("\n  Out of bounds error for new_data dest_end:{} new_data.len:{}", .{ dest_end, new_data.len });
                return TensorError.IndexOutOfBounds;
            }

            @memcpy(new_data[dest_start..dest_end], tensor.data[src_start..src_end]);

            // Update the offset for the next copy
            offset += copy_size;
        }
    }

    // Return the concatenated tensor
    return Tensor(T){
        .data = new_data,
        .size = total_size,
        .shape = new_shape,
        .allocator = allocator,
    };
}

/// Calculate strides for a given shape
pub fn calculateStrides(shape: []usize, allocator: *const std.mem.Allocator) ![]usize {
    const len = shape.len;
    const strides = try allocator.alloc(usize, len);
    if (len == 0) return strides; // Handle scalar tensor
    strides[len - 1] = 1;
    for (1..len) |i| {
        strides[len - 1 - i] = strides[len - i] * shape[len - i];
    }
    return strides;
}

/// Returns a Tensor self transposed. Does not modify self.
/// It sobstitute init(), but defer yourTensor.deinit() is still necessary.
pub fn transpose2D(comptime T: type, t: *Tensor(T)) !Tensor(T) {
    if (t.shape.len != 2) {
        return error.InvalidDimension; // For simplicity, let's focus on 2D for now
    }

    const allocator = t.allocator;

    // Shape of the transposed tensor
    const transposed_shape: [2]usize = [_]usize{ t.shape[1], t.shape[0] };
    const tensorShape = try allocator.alloc(usize, t.shape.len);
    @memcpy(tensorShape, &transposed_shape);

    // Allocate space for transposed data
    const transposed_data = try allocator.alloc(T, t.size);

    // Perform the transposition
    for (0..t.shape[0]) |i| {
        for (0..t.shape[1]) |j| {
            // For 2D tensor, flatten the index and swap row/column positions
            const old_idx = i * t.shape[1] + j;
            const new_idx = j * t.shape[0] + i;
            transposed_data[new_idx] = t.data[old_idx];
        }
    }

    return Tensor(T){
        .data = transposed_data,
        .size = t.size,
        .shape = tensorShape,
        .allocator = allocator,
    };
}

/// Returns a Tensor self transposed.
/// OSS! Does not modify self.data!! it only changes the shape! so it is necessary to acces it trough get_flatten_index()
/// By default, it transposes the tensor to the reverse shape.
pub fn transposeDefault(comptime T: type, t: *Tensor(T)) !Tensor(T) {
    // Reverse the shape of the tensor
    const tensorShape = try t.allocator.alloc(usize, t.shape.len);
    for (0..t.shape.len) |i| {
        tensorShape[i] = t.shape.len - 1 - i;
    }

    return transpose(T, t, tensorShape);
}

/// Returns a Tensor self transposed. Does not modify self.
fn transpose(comptime T: type, t: *Tensor(T), perms: []usize) !Tensor(T) {
    defer t.allocator.free(perms);
    const num_dims = t.shape.len;
    if (perms.len != num_dims) {
        return error.InvalidDimension;
    }

    // Check that the permutation is valid
    var bitmap = try t.allocator.alloc(bool, perms.len);
    defer t.allocator.free(bitmap);

    for (perms) |perm| {
        if (perm >= perms.len) {
            return error.InvalidPermutation;
        }
        if (bitmap[perm] == true) {
            return error.InvalidPermutation;
        }
        bitmap[perm] = true;
    }

    // Allocate space for the new shape
    const new_shape = try t.allocator.alloc(usize, num_dims);
    for (0..num_dims) |i| {
        new_shape[i] = t.shape[perms[i]];
    }
    defer t.allocator.free(new_shape);

    // Create the new tensor
    const new_tensor = try Tensor(T).fromShape(t.allocator, new_shape);

    // Copy data to the new tensor
    for (0..t.size) |i| {
        new_tensor.data[i] = t.data[i];
    }

    return new_tensor;
}

/// Method to add a top&bottom padding and a left&right padding.
/// At the moment the function only supports 2 padding params, but the method
/// is already set to have different left, right, top and bottom padding values.
pub fn addPaddingAndDilation(
    comptime T: type,
    t: *Tensor(T),
    upDownPadding: usize,
    leftRightPadding: usize,
    verticalDil: usize,
    horizontalDil: usize,
) !void {

    //checks on padding dim (usize is alway >= 0)
    if (t.shape.len < 2) return TensorError.TooSmallToPadding;

    const upPadding = upDownPadding;
    const downPadding = upDownPadding;
    const leftPadding = leftRightPadding;
    const rightPadding = leftRightPadding;
    const dim = t.shape.len;

    const new_row_numb = t.shape[dim - 2] + upPadding + downPadding + verticalDil * (t.shape[dim - 2] - 1);
    const new_col_numb = t.shape[dim - 1] + leftPadding + rightPadding + horizontalDil * (t.shape[dim - 1] - 1);
    //std.debug.print("\n new_row_numb: {} new_col_numb:{}", .{ new_row_numb, new_col_numb });

    //compute new shape
    const new_shape = try t.allocator.alloc(usize, dim);
    @memcpy(new_shape, t.shape);
    new_shape[dim - 1] = new_col_numb;
    new_shape[dim - 2] = new_row_numb;

    //compute new size
    var new_total_size: usize = 1;
    for (new_shape) |size_i| {
        new_total_size *= size_i;
    }

    //alloc new tensor.data memory space to all zero
    const new_data = try t.allocator.alloc(T, new_total_size);
    @memset(new_data, 0);

    const new_matrix_dim = new_row_numb * new_col_numb;
    const total_number_2DMatrices = new_total_size / new_matrix_dim;
    const old_matrix_dim = t.shape[dim - 2] * t.shape[dim - 1];
    const old_total_number_2DMatrices = t.size / old_matrix_dim; //just for check assertion
    std.debug.assert(total_number_2DMatrices == old_total_number_2DMatrices);

    for (0..total_number_2DMatrices) |matix_i| {
        const num_elem_prec_new_matr = matix_i * new_matrix_dim;
        const num_elem_prec_old_matr = matix_i * old_matrix_dim;
        var i = upPadding;
        var old_row: usize = 0;
        while (i < new_row_numb - downPadding) : (i += (1 + verticalDil)) {
            var j = leftPadding;
            var old_col: usize = 0;
            while (j < new_col_numb - rightPadding) : (j += (1 + horizontalDil)) {
                const idx_new_matr = num_elem_prec_new_matr + i * new_col_numb + j;
                const idx_old_matr = num_elem_prec_old_matr + old_row * (t.shape[dim - 1]) + old_col;
                new_data[idx_new_matr] = t.data[idx_old_matr];
                old_col += 1;
            }
            old_row += 1;
        }
    }

    //free all old attributes and setting new ones
    t.allocator.free(t.data);
    t.allocator.free(t.shape);

    t.shape = new_shape;
    t.data = new_data;
    t.size = new_total_size;
}

/// Helper function to flip (rotate 180 degrees horizontaly and vertically) the kernel in convolution or any other matix 2D
/// ex:
///  flip( [[a, b], [c, d], [e, f]] ) = [[f, e], [d, c], [b, a]]
pub fn flip(comptime T: type, kernel: *Tensor(T)) !Tensor(T) {
    const kernel_dim = kernel.shape.len;
    const kernel_row = kernel.shape[kernel_dim - 2];
    const kernel_cols = kernel.shape[kernel_dim - 1];
    const matrix_dim = kernel_cols * kernel_row;

    //create and initialize the new shape
    const flipped_shape = try kernel.allocator.alloc(usize, kernel.shape.len);
    defer kernel.allocator.free(flipped_shape);
    @memcpy(flipped_shape, kernel.shape);

    var flipped_kernel = try Tensor(T).fromShape(kernel.allocator, flipped_shape);

    const total_number_2DMatrices = flipped_kernel.size / matrix_dim;

    for (0..total_number_2DMatrices) |matix_i| {
        for (0..kernel_row) |i| {
            for (0..kernel_cols) |j| {
                flipped_kernel.data[(matix_i + 1) * matrix_dim - (i * kernel_cols + j + 1)] = kernel.data[matix_i * matrix_dim + i * kernel_cols + j];
            }
        }
    }

    return flipped_kernel;
}
