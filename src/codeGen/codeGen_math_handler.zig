const std = @import("std");
const Tensor = @import("tensor").Tensor;
const tensorMath = @import("tensor_math");
const ModelOnnx = @import("onnx").ModelProto;
const DataType = @import("onnx").DataType;
const allocator = @import("pkgAllocator").allocator;

// --- proto libs
const TensorProto = @import("onnx").TensorProto;
const NodeProto = @import("onnx").NodeProto;
const GraphProto = @import("onnx").GraphProto;
const AttributeType = @import("onnx").AttributeType;

// --- codeGen libs
const ReadyNode = @import("codeGen_predict.zig").ReadyNode;
const ReadyTensor = @import("codeGen_predict.zig").ReadyTensor;
const utils = @import("codeGen_utils.zig");

// ----------------------------------- MATH -----------------------------------

/// This method map and write the ONNX operations with the Zant LeanTensorMath mathods
/// Follow the link for details: https://onnx.ai/onnx/operators/?utm_source=chatgpt.com
pub fn write_math_op(writer: std.fs.File.Writer, node: *ReadyNode) !void {
    try writer.print(
        \\
        \\
        \\   //forwarding operation : {s}
        \\   //parameters:
        \\   //   inputs: 
    , .{node.*.nodeProto.*.op_type});

    //write the inputs
    for (node.inputs.items) |input| {
        try writer.print(
            \\
            \\   //      -> {s} 
        , .{input.name});
    }
    try writer.print(
        \\
        \\   //    outputs: 
    , .{});

    //write the outputs
    for (node.outputs.items) |output| {
        try writer.print(
            \\
            \\   //      <- {s} 
        , .{output.name});
    }

    if (std.mem.eql(u8, node.nodeProto.op_type, "Add")) {
        try writer.writeAll("// Handle Add\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "AveragePool")) {
        try writer.writeAll("// Handle AveragePool\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "BatchNormalization")) {
        try writer.writeAll("// Handle BatchNormalization\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Ceil")) {
        try write_ceil(writer, node);
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Concat")) {
        try writer.writeAll("// Handle Concat\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Constant")) {
        try writer.writeAll("// Handle Constant\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Conv")) {
        try writer.writeAll("// Handle Conv\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Div")) {
        try write_div(writer, node);
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Flatten")) {
        try writer.writeAll("// Handle Flatten\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Gather")) {
        try writer.writeAll("// Handle Gather\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Gemm")) {
        try write_gemm(writer, node);
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "LeakyRelu")) {
        try write_leakyReLu(writer, node);
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "LogSoftmax")) {
        try writer.writeAll("// Handle LogSoftmax\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "MatMul")) {
        try writer.writeAll("// Handle MatMul\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "MaxPool")) {
        try writer.writeAll("// Handle MaxPool\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Mul")) {
        try write_mul(writer, node);
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "OneHot")) {
        try writer.writeAll("// Handle OneHot\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Relu")) {
        try write_ReLU(writer, node);
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Reshape")) {
        try writer.writeAll("// Handle Relu\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Resize")) {
        try writer.writeAll("// Handle Resize\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Sigmoid")) {
        try write_sigmoid(writer, node);
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Softmax")) {
        try write_softmax(writer, node);
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Slice")) {
        try writer.writeAll("// Handle Slice\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Split")) {
        try writer.writeAll("// Handle Split\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Sub")) {
        try writer.writeAll("// Handle Sub\n");
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Sum")) {
        try write_sum(writer, node);
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Tanh")) {
        try write_tanh(writer, node);
    } else if (std.mem.eql(u8, node.nodeProto.op_type, "Transpose")) {
        try writer.writeAll("// Handle Transpose\n");
    } else {
        return error.OperationNotSupported;
    }

    try writer.writeAll(" catch return;");
}

inline fn write_ceil(writer: std.fs.File.Writer, node: *ReadyNode) !void {
    // https://onnx.ai/onnx/operators/onnx__Ceil.html
    // INPUTS:
    //      - A (heterogeneous) - T:
    // OUTPUTS:
    //      - B (heterogeneous) - T: The ceil values of the input tensor computed element-wise, same type

    _ = try writer.print(
        \\
        \\    tensMath.ceil_lean(T, &tensor_{s}, &tensor_{s})
    , .{
        try utils.getSanitizedName(node.inputs.items[0].name), // Input tensor A
        try utils.getSanitizedName(node.outputs.items[0].name), // Output tensor B
    });
}

inline fn write_div(writer: std.fs.File.Writer, node: *ReadyNode) !void {
    // https://onnx.ai/onnx/operators/onnx__Div.html
    // INPUTS:
    //      - A (heterogeneous) - T: First operand.
    //      - B (heterogeneous) - T: Second operand.
    // OUTPUTS:
    //      - C (heterogeneous) - T: Result, has same element type as two inputs.

    _ = try writer.print(
        \\
        \\    tensMath.div_lean(T, &tensor_{s}, &tensor_{s}, &tensor_{s})
    , .{
        try utils.getSanitizedName(node.inputs.items[0].name), // Input tensor A
        try utils.getSanitizedName(node.inputs.items[1].name), // Input tensor B
        try utils.getSanitizedName(node.outputs.items[0].name), // Output tensor C
    });
}

inline fn write_gemm(writer: std.fs.File.Writer, node: *ReadyNode) !void {
    // https://onnx.ai/onnx/operators/onnx__Gemm.html
    // INPUTS:
    //      - Input tensor A. The shape of A should be (M, K) if transA is 0, or (K, M) if transA is non-zero.
    //      - Input tensor B. The shape of B should be (K, N) if transB is 0, or (N, K) if transB is non-zero.
    //      - Optional input tensor C. If not specified, the computation is done as if C is a scalar 0. The shape of C should be unidirectional broadcastable to (M, N).
    // OUTPUTS:
    //      - Output tensor of shape (M, N).
    // ATTRIBUTES:
    //      - alpha. FLOAT (default is '1.0'): Scalar multiplier for the product of input tensors A * B.
    //      - beta - FLOAT (default is '1.0'): Scalar multiplier for input tensor C.
    //      - transA - INT (default is '0'): Whether A should be transposed
    //      - transB - INT (default is '0'): Whether B should be transposed

    var alpha: f32 = 1.0;
    var beta: f32 = 1.0;
    var transA: bool = false;
    var transB: bool = false;

    for (node.nodeProto.attribute) |attr| {
        if (std.mem.indexOf(u8, attr.name, "alpha")) |_| {
            if (attr.type == AttributeType.FLOAT) alpha = attr.f else return error.GemmAphaNotFLOAT;
        } else if (std.mem.indexOf(u8, attr.name, "beta")) |_| {
            if (attr.type == AttributeType.FLOAT) beta = attr.f else return error.GemmBetaNotFLOAT;
        } else if (std.mem.indexOf(u8, attr.name, "transA")) |_| {
            if (attr.type == AttributeType.INT) transA = if (attr.i != 0) false else true else return error.GemmTransANotINT;
        } else if (std.mem.indexOf(u8, attr.name, "transB")) |_| {
            if (attr.type == AttributeType.INT) transB = if (attr.i != 0) false else true else return error.GemmTransBNotINT;
        }
    }

    var c_tensor_string: []u8 = undefined;
    // Input Tensor C is optional! verify the presence
    if (node.inputs.items.len == 3) {
        const C_name = try utils.getSanitizedName(node.inputs.items[2].name);
        c_tensor_string = try std.mem.concat(allocator, u8, &[_][]const u8{ ", @constCast(&tensor_", C_name, ")" });
    } else {
        c_tensor_string = "";
    }

    _ = try writer.print(
        \\
        \\    tensMath.gemm_lean(T, &tensor_{s}, @constCast(&tensor_{s}) {s}, {}, {}, {}, {}, &tensor_{s} )
    , .{
        try utils.getSanitizedName(node.inputs.items[0].name), // Input tensor A
        try utils.getSanitizedName(node.inputs.items[1].name), // Input tensor B
        c_tensor_string,
        alpha,
        beta,
        transA,
        transB,
        try utils.getSanitizedName(node.outputs.items[0].name), // Output
    });
}

inline fn write_leakyReLu(writer: std.fs.File.Writer, node: *ReadyNode) !void {
    // https://onnx.ai/onnx/operators/onnx__LeakyRelu.html
    // INPUTS:
    //      - A (heterogeneous) - T:
    // OUTPUTS:
    //      - B (heterogeneous) - T: Tensor containing results of leakyReLu applied element-wise to tensor A

    var slope: f32 = 0.01;

    for (node.nodeProto.attribute) |attr| {
        if (std.mem.indexOf(u8, attr.name, "slope")) |_| {
            if (true
            // attr.type == type_of_tensor_A
            ) slope = attr.f else return error.slopeTypeNotMatching;
        }
    }

    _ = try writer.print(
        \\
        \\    tensMath.leakyReLU_lean(T, &tensor_{s}, {}, &tensor_{s})
    , .{
        try utils.getSanitizedName(node.inputs.items[0].name), // Input tensor A
        slope,
        try utils.getSanitizedName(node.outputs.items[0].name), // Output tensor B
    });
}

inline fn write_mul(writer: std.fs.File.Writer, node: *ReadyNode) !void {
    // https://onnx.ai/onnx/operators/onnx__Mul.html
    // INPUTS:
    //      - A (heterogeneous) - T: First operand.
    //      - B (heterogeneous) - T: Second operand.
    // OUTPUTS:
    //      - C (heterogeneous) - T: Result, has same element type as two inputs.

    _ = try writer.print(
        \\
        \\    tensMath.mul_lean(T, &tensor_{s}, @constCast(&tensor_{s}), &tensor_{s})
    , .{
        try utils.getSanitizedName(node.inputs.items[0].name), // Input tensor A
        try utils.getSanitizedName(node.inputs.items[1].name), // Input tensor B
        try utils.getSanitizedName(node.outputs.items[0].name), // Output tensor C
    });
}

inline fn write_ReLU(writer: std.fs.File.Writer, node: *ReadyNode) !void {
    //node.inputs.items[0] -> input
    //node.outputs.items[0] -> output

    _ = try writer.print(
        \\
        \\    tensMath.ReLU_lean(T, &tensor_{s}, &tensor_{s})
    , .{
        try utils.getSanitizedName(node.inputs.items[0].name),
        try utils.getSanitizedName(node.outputs.items[0].name),
    });
}

inline fn write_sigmoid(writer: std.fs.File.Writer, node: *ReadyNode) !void {
    //node.inputs.items[0] -> input
    //node.outputs.items[0] -> output

    _ = try writer.print(
        \\
        \\    tensMath.sigmoid_lean(T, &tensor_{s}, &tensor_{s})
    , .{
        try utils.getSanitizedName(node.inputs.items[0].name),
        try utils.getSanitizedName(node.outputs.items[0].name),
    });
}

inline fn write_softmax(writer: std.fs.File.Writer, node: *ReadyNode) !void {
    //node.inputs.items[0] -> input
    //node.outputs.items[0] -> output

    _ = try writer.print(
        \\
        \\    tensMath.softmax_lean(T, &tensor_{s}, &tensor_{s})
    , .{
        try utils.getSanitizedName(node.inputs.items[0].name),
        try utils.getSanitizedName(node.outputs.items[0].name),
    });
}

inline fn write_sum(writer: std.fs.File.Writer, node: *ReadyNode) !void {
    // https://onnx.ai/onnx/operators/onnx__Sum.html
    // INPUTS:
    //      - list of tensors
    // OUTPUTS:
    //      - sum (heterogeneous) - T: Output tensor.

    //Writing the tensor list with all the inputs
    _ = try writer.print(
        \\
        \\    const my_tensor_list = [_]*Tensor(T){{
    , .{});

    for (node.inputs.items, 0..) |tens, idx| {
        if (idx > 0) {
            _ = try writer.print(", ", .{});
        }
        _ = try writer.print(
            \\tensor_{s}
        , .{try utils.getSanitizedName(tens.name)});
    }

    _ = try writer.print("}}", .{});

    _ = try writer.print(
        \\
        \\    tensMath.sum_tensor_list_lean(T, T, &my_tensor_list, &tensor_{s})
    , .{try utils.getSanitizedName(node.outputs.items[0].name)});
}

inline fn write_tanh(writer: std.fs.File.Writer, node: *ReadyNode) !void {
    // https://onnx.ai/onnx/operators/onnx__Tanh.html
    // INPUTS:
    //      - A (heterogeneous) - T:
    // OUTPUTS:
    //      - B (heterogeneous) - T: The hyperbolic tangent values of the input tensor computed element-wise, same type

    _ = try writer.print(
        \\
        \\    tensMath.tanh_lean(T, &tensor_{s}, &tensor_{s})
    , .{
        try utils.getSanitizedName(node.inputs.items[0].name), // Input tensor A
        try utils.getSanitizedName(node.outputs.items[0].name), // Output tensor B
    });
}

// ----------------------------------- SHAPE inference -----------------------------------

pub fn compute_output_shape(readyNode: *ReadyNode) !void {
    if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Add")) {
        // https://onnx.ai/onnx/operators/onnx__Add.html
        readyNode.outputs.items[0].shape = readyNode.inputs.items[1].shape;
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Ceil")) {
        // https://onnx.ai/onnx/operators/onnx__Ceil.html
        try compute_ceil_output_shape(readyNode);
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Concat")) {
        // TODO
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Constant")) {
        // https://onnx.ai/onnx/operators/onnx__Constant.html
        try compute_constant_output_shape(readyNode);
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Conv")) {
        // https://onnx.ai/onnx/operators/onnx__Conv.html
        try compute_conv_output_shape(readyNode);
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Div")) {
        // https://onnx.ai/onnx/operators/onnx__Div.html
        readyNode.outputs.items[0].shape = readyNode.inputs.items[1].shape;
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Tanh")) {
        // https://onnx.ai/onnx/operators/onnx__Tanh.html
        readyNode.outputs.items[0].shape = readyNode.inputs.items[0].shape;
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Flatten")) {
        // TODO
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Gather")) {
        // TODO
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Gemm")) {
        // https://onnx.ai/onnx/operators/onnx__Gemm.html
        try compute_gemm_output_shape(readyNode);
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "LeakyRelu")) {
        // https://onnx.ai/onnx/operators/onnx__LeakyRelu.html
        try compute_leakyReLU_output_shape(readyNode);
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "LogSoftmax")) {
        // TODO
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "MatMul")) {
        // TODO
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "MaxPool")) {
        // TODO
        //try compute_maxPool_output_shape(readyNode);
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Mul")) {
        // https://onnx.ai/onnx/operators/onnx__Mul.html
        try compute_mul_output_shape(readyNode);
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "OneHot")) {
        // TODO
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Relu")) {
        // https://onnx.ai/onnx/operators/onnx__Relu.html
        try compute_ReLU_output_shape(readyNode);
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Reshape")) {
        // TODO
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Resize")) {
        // TODO
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Shape")) {
        // TODO
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Sigmoid")) {
        // TODO
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Softmax")) {
        // https://onnx.ai/onnx/operators/onnx__Softmax.html
        try compute_softmax_output_shape(readyNode);
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Slice")) {
        // TODO
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Split")) {
        // TODO
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Sub")) {
        // TODO
    } else if (std.mem.eql(u8, readyNode.nodeProto.op_type, "Transpose")) {
        // TODO
    } else {
        std.debug.print("\n\n ERROR! output shape computation for {s} is not available in codeGen_math_handler.compute_output_shape() \n\n", .{readyNode.nodeProto.op_type});
        return error.OperationNotSupported;
    }
}

// ---------------- SHAPE COMPUTATION METHODS ----------------

inline fn compute_constant_output_shape(readyNode: *ReadyNode) !void {
    readyNode.outputs.items[0].shape = try utils.getConstantTensorDims(readyNode.nodeProto);
}

inline fn compute_ceil_output_shape(readyNode: *ReadyNode) !void {
    readyNode.outputs.items[0].shape = readyNode.inputs.items[0].shape;
}

inline fn compute_leakyReLU_output_shape(readyNode: *ReadyNode) !void {
    readyNode.outputs.items[0].shape = readyNode.inputs.items[0].shape;
}

inline fn compute_ReLU_output_shape(readyNode: *ReadyNode) !void {
    readyNode.outputs.items[0].shape = readyNode.inputs.items[0].shape;
}

inline fn compute_softmax_output_shape(readyNode: *ReadyNode) !void {
    readyNode.outputs.items[0].shape = readyNode.inputs.items[0].shape;
}

inline fn compute_gemm_output_shape(readyNode: *ReadyNode) !void {
    //inputs.items[0] -> input Tensor
    //inputs.items[1] -> weight Tensor
    //inputs.items[2] -> bias Tensor
    //
    //output shape = bias shape by definition of gemm

    readyNode.outputs.items[0].shape = readyNode.inputs.items[2].shape;
}

inline fn compute_mul_output_shape(readyNode: *ReadyNode) !void {
    //inputs.items[0] ->  Tensor a
    //inputs.items[1] ->  Tensor b
    //
    //output shape =[... , a.rows , b.cols ]

    const shape_len = readyNode.outputs.items[0].shape.len;

    var newShape = try allocator.alloc(i64, shape_len);
    @memcpy(newShape, readyNode.inputs.items[0].shape);
    newShape[shape_len - 1] = readyNode.inputs.items[1].shape[shape_len - 1];

    readyNode.outputs.items[0].shape = newShape;
}

inline fn compute_conv_output_shape(readyNode: *ReadyNode) !void {
    //inputs.items[0] -> input Tensor (X)
    //inputs.items[1] -> kernel Tensor (W)
    //
    //output shape-> input Tensor

    //attributes:
    //nodeProtop.attribute[0] = kernel_shape -> TODO: search it, it is not fixed to index 0
    //nodeProtop.attribute[1] = strides -> TODO: search it, it is not fixed to index 1

    const input_shape: []const i64 = readyNode.inputs.items[0].shape;
    const kernel_shape: []const i64 = readyNode.inputs.items[1].shape;
    const stride = readyNode.nodeProto.attribute[1].ints;

    // DEBUG
    std.debug.print("\n====== compute_conv_output_shape node: {s}======", .{readyNode.nodeProto.name.?});
    std.debug.print("\n input_shape: []usize = {any}", .{try utils.i64SliceToUsizeSlice(input_shape)});
    std.debug.print("\n kernel_shape: []usize = {any} ", .{try utils.i64SliceToUsizeSlice(kernel_shape)});

    readyNode.outputs.items[0].shape = try utils.usizeSliceToI64Slice(
        @constCast(
            &try tensorMath.get_convolution_output_shape(
                try utils.i64SliceToUsizeSlice(input_shape),
                try utils.i64SliceToUsizeSlice(kernel_shape),
                try utils.i64SliceToUsizeSlice(stride),
            ),
        ),
    );
}

// inline fn compute_maxPool_output_shape(readyNode: *ReadyNode) !void {
//     readyNode.outputs.items[0].shape = try utils.usizeSliceToI64Slice(
//         @constCast(
//             &try tensorMath.get_convolution_output_shape(
//                 try utils.i64SliceToUsizeSlice(input_shape),
//                 try utils.i64SliceToUsizeSlice(kernel_shape),
//                 try utils.i64SliceToUsizeSlice(stride),
//             ),
//         ),
//     );
// }
